# Chapter 12: Stream Processing

## Core Thesis
Stream processing is batch processing on an unbounded, continuously arriving dataset.
The core challenges that distinguish it from batch: handling late data, windowing time,
maintaining state across events, and providing exactly-once guarantees across stateful
operations. Kafka is the reference architecture — understand it deeply.

---

## Event Streams vs Polling

```mermaid
graph LR
    subgraph "Polling"
        P[Consumer polls DB every 5s] -->|reads all new rows| P2[Processes]
        P2 --> P3[Waits 5s → repeat]
        note1[High latency: up to 5s delay<br/>Wasteful: most polls return nothing<br/>DB load: constant queries]
    end

    subgraph "Event Stream"
        W[Writer publishes event] -->|immediately| BR[Broker]
        BR -->|push| C[Consumer receives in ms]
        note2[Low latency: sub-second<br/>Efficient: consumer only wakes on events]
    end
```

---

## Messaging Systems — Design Dimensions

```mermaid
graph TD
    MSG[Messaging Systems]
    MSG --> D1{What if consumer is slower than producer?}
    D1 --> DP[Drop messages]
    D1 --> BF[Buffer in queue]
    D1 --> BP[Backpressure — slow producer]

    MSG --> D2{Durability?}
    D2 --> M[In-memory only — fast, lossy]
    D2 --> DK[Written to disk — durable]
    D2 --> REP[Replicated — HA]
```

### Traditional Message Brokers (RabbitMQ, ActiveMQ, SQS)

```mermaid
graph LR
    P[Producer] --> Q[Queue]
    Q --> C1[Consumer 1]
    Q --> C2[Consumer 2]

    note1[Messages deleted after ACK<br/>Consumers maintain offset implicitly<br/>Low storage footprint<br/>Can't replay]
```

**Patterns**:
- **Load balancing**: Message delivered to one consumer (work queue)
- **Fan-out**: Message delivered to all consumers (pub/sub)

### Log-Based Message Brokers (Kafka, Kinesis, Pulsar)

```mermaid
graph TD
    subgraph "Kafka Topic: orders (3 partitions)"
        P0[Partition 0: offset 0,1,2,3...]
        P1[Partition 1: offset 0,1,2,3...]
        P2[Partition 2: offset 0,1,2,3...]
    end

    PROD[Producer] -->|hash(key) → partition| P0
    PROD --> P1
    PROD --> P2

    CG1[Consumer Group A<br/>Analytics] --> P0
    CG1 --> P1
    CG1 --> P2

    CG2[Consumer Group B<br/>Notifications] --> P0
    CG2 --> P1
    CG2 --> P2

    note1[Each consumer group tracks its own offset<br/>Messages NOT deleted after read<br/>Multiple consumer groups read independently<br/>Can replay from any offset]
```

| Dimension | Traditional Broker | Log-Based (Kafka) |
|-----------|-------------------|-------------------|
| Message retention | Deleted on ACK | Kept for configured period |
| Replay | ❌ No | ✅ Any offset, any time |
| Consumer groups | Complex | Native — each group has its own offset |
| Throughput | Moderate | Very high (sequential disk writes) |
| Ordering | Within queue | Within partition |
| Fan-out | Yes | Yes (multiple consumer groups) |

---

## Kafka Internals

```mermaid
graph LR
    subgraph "Producer"
        KEY[key=user_id] -->|hash mod partitions| PART[Partition 2]
        PART --> BATCH[Batch messages]
        BATCH -->|compress + send| LEADER[Partition Leader]
    end

    subgraph "Broker Cluster"
        LEADER -->|replicate| REP1[Replica 1]
        LEADER -->|replicate| REP2[Replica 2]
        LEADER -->|ISR ACK| ACK[Producer ACK]
    end

    subgraph "Consumer"
        CONSUMER[Consumer in group] -->|poll| LEADER
        LEADER -->|batch of messages| CONSUMER
        CONSUMER -->|commit offset| CK[__consumer_offsets topic]
    end
```

**Key design choice**: Log-structured storage (sequential appends) → very high write
throughput. Consumer reads sequentially → OS page cache is highly effective.

**ISR (In-Sync Replicas)**: Leader only ACKs when all ISR replicas have written.
`acks=all` (producer setting) + `min.insync.replicas=2` = strong durability.

---

## Change Data Capture (CDC)

```mermaid
graph LR
    subgraph "Database"
        PG[PostgreSQL<br/>WAL: logical replication slot]
        MY[MySQL<br/>binlog]
    end

    CDC[Debezium / Maxwell] -->|reads WAL/binlog| PG
    CDC -->|reads WAL/binlog| MY
    CDC -->|events| KAFKA[Kafka Topic<br/>outbox.orders]

    KAFKA --> ES[Elasticsearch<br/>search index]
    KAFKA --> CACHE[Redis<br/>cache invalidation]
    KAFKA --> DWH[Data Warehouse<br/>analytics]
    KAFKA --> NOTIF[Notification Service]
```

**CDC vs dual-write**:
- **Dual write**: App writes to DB and Kafka simultaneously → race condition, partial failure risk
- **CDC**: DB write is the single source of truth; Kafka event is derived from WAL
  → guaranteed consistency between DB and downstream systems

**The outbox pattern** (safer than CDC for transactional guarantee):
```sql
BEGIN;
INSERT INTO orders VALUES (...);
INSERT INTO outbox (event_type, payload) VALUES ('order_created', '...');
COMMIT;
-- CDC publishes outbox rows to Kafka, then deletes them
```

---

## Event Sourcing

```mermaid
graph LR
    subgraph "Traditional CRUD"
        CRUD[UPDATE account SET balance=500] --> STATE[Current state only<br/>History lost]
    end

    subgraph "Event Sourcing"
        E1[AccountOpened: balance=0]
        E2[MoneyDeposited: amount=500]
        E3[MoneyWithdrawn: amount=200]
        E1 --> E2 --> E3
        E3 -->|replay all events| CURR[Current state: balance=300]
        E3 -->|snapshot| SNAP[Snapshot: balance=300 at event 3]
    end
```

**Event sourcing benefits**:
- Complete audit trail
- Temporal queries ("what was the state at time T?")
- Replay to rebuild projections (search index, caches, new views)
- Debugging — exactly reproduce the sequence of events that led to a bug

**Event sourcing costs**:
- Storage grows forever (mitigated by snapshots + log compaction)
- Eventual consistency — projections lag behind the event log
- Schema evolution is hard (old events must still be readable)

---

## Uses of Stream Processing

### 1. Complex Event Processing (CEP)

Detect patterns across sequences of events in real time:

```mermaid
graph LR
    EVENTS[Event stream: user actions] --> CEP[CEP Engine<br/>Esper, Flink CEP]
    CEP -->|pattern: login → view product → abandon cart| TRIGGER[Alert: send discount email]
    CEP -->|pattern: 3 failed logins in 60s| FRAUD[Fraud alert]
    CEP -->|pattern: temperature spike + pressure drop| MAINT[Maintenance alert]
    note1[Queries are patterns over time windows<br/>not queries on stored data]
```

CEP inverts the typical query model: instead of storing data and running queries, you store queries (patterns) and run data through them.

### 2. Stream Analytics

Aggregate metrics continuously over time windows:

```mermaid
graph LR
    METRICS[Metric events: request latency, error rate] --> WINDOW[Tumbling window: 1-minute buckets]
    WINDOW --> AGG[p99 latency, error rate per service]
    AGG --> DASH2[Real-time dashboard<br/>Grafana / Datadog]
    AGG --> ALERT[Alert if p99 > 500ms]
```

**Examples**: Kafka Streams, Apache Flink, Spark Structured Streaming.
Used for: operational dashboards, fraud detection, A/B test metrics, IoT monitoring.

### 3. Incremental View Maintenance

Maintain a continuously updated materialized view as new events arrive:

```mermaid
graph LR
    EVENTS2[Event stream: order placed / cancelled] --> IVM[Incremental View Maintenance]
    IVM -->|update| VIEW[orders_summary view:<br/>total_orders, total_revenue by product]
    
    note1[Instead of recomputing the view from scratch<br/>apply each event as a delta update<br/>O(event) not O(entire dataset)]
```

**Why it's hard**: Retractions (cancellations, updates) must undo the effect of previous events.
If an order is cancelled, the running sum must decrease. This requires keeping state.

**Examples**: Materialize (full SQL incrementally maintained), Flink SQL, ksqlDB.

---

## Reasoning About Time — Window Types

```mermaid
graph LR
    subgraph "Tumbling Window (fixed, non-overlapping)"
        TW["[0:00–1:00] → emit<br/>[1:00–2:00] → emit<br/>[2:00–3:00] → emit"]
        note_t[Each event belongs to exactly one window<br/>Use: hourly metrics, rate limiting]
    end

    subgraph "Hopping Window (fixed, overlapping)"
        HW["size=10min, hop=5min:<br/>[0:00–0:10], [0:05–0:15], [0:10–0:20]..."]
        note_h[Each event may be in multiple windows<br/>Use: smoothed metrics, sliding averages]
    end

    subgraph "Sliding Window"
        SW["Always shows last N minutes from 'now'<br/>'Events in the last 1 hour'"]
        note_s[Continuous window moving with time<br/>Use: rate limiting per user]
    end

    subgraph "Session Window"
        SEW["Events: 00:00, 00:02, 00:05 → gap → 01:30, 01:32<br/>Session 1: [00:00–00:05]<br/>Session 2: [01:30–01:32]"]
        note_se[Window closes after inactivity gap<br/>Use: user session analysis]
    end
```

### Event Time vs Processing Time — The Core Time Problem

```mermaid
graph LR
    E1["Event: occurred at 09:58<br/>arrives at processor at 10:03 (5min late)"]
    E2["Event: occurred at 10:01<br/>arrives at processor at 10:02 (1min late)"]

    subgraph "Processing-time window [10:00–10:05]"
        P1[Includes E1 and E2<br/>based on arrival time<br/>Simple but inaccurate]
    end

    subgraph "Event-time window [09:58–10:03]"
        P2[Must hold window open<br/>waiting for late events<br/>Correct but needs watermark]
    end
```

**Watermark**: The system's estimate of "we've received all events up to time T."
When watermark reaches T, the window [T-duration, T] can be closed and emitted.

**Late data strategies**:
1. Drop late events (fire-and-forget, simple)
2. Re-trigger window with late arrivals (output corrections)
3. Route to side output for separate handling (audit trail of late data)

---

## Event-Driven Architectures vs RPC

```mermaid
graph LR
    subgraph "RPC / REST: synchronous coupling"
        A[Service A] -->|"POST /order (waits)"| B[Service B]
        B -->|"200 OK (must respond)"| A
        note1[A is blocked<br/>B must be available<br/>Cascade failures]
    end

    subgraph "Event-driven: temporal decoupling"
        C[Service C] -->|emit OrderPlaced event| KF[Kafka]
        KF -->|whenever ready| D[Service D]
        KF -->|independently| E[Service E]
        note2[C doesn't wait<br/>D and E can be down temporarily<br/>Buffer events until ready]
    end
```

**When event-driven wins**: Multiple consumers for the same event, variable processing
rates, need for replay, adding new consumers without changing producers.

**When RPC wins**: Synchronous response needed (read data), simpler debugging, strong
ordering guarantees required, or the latency of an async roundtrip is unacceptable.

---

## Stream Processing

### Window Types

```mermaid
graph LR
    subgraph "Tumbling Window (fixed, non-overlapping)"
        TW1[00:00–01:00] --- TW2[01:00–02:00] --- TW3[02:00–03:00]
    end

    subgraph "Sliding Window (overlapping)"
        SW1[00:00–01:00]
        SW2[00:30–01:30]
        SW3[01:00–02:00]
    end

    subgraph "Session Window (activity-based)"
        SE1[Events: 00:00, 00:05, 00:08] -->|gap>30min| SE2[Events: 01:30, 01:32]
    end
```

### Time Semantics

```mermaid
graph LR
    subgraph "Event Time vs Processing Time"
        ET[Event Time<br/>When event actually occurred] 
        PT[Processing Time<br/>When system processes event]
        LAG[Lag: network, retries, backpressure<br/>Events arrive out of order]
        ET --> LAG --> PT
    end
```

**Watermarks**: A heuristic estimate of "we've seen all events up to time T".
When watermark reaches T, window [T-window, T] is closed and emitted.

```mermaid
graph LR
    EVENTS[Events arrive with timestamps: 10, 8, 12, 9, 15, 7]
    WMARK[Watermark at t=12: max_event_time - max_lateness<br/>= 15 - 5 = 10]
    CLOSE[Close window [0,10]: event at t=7 arrives late]
    LATE[Late event: drop, or emit to side output]
```

---

## Stream Joins

### Stream-Stream Join (Windowed)

```mermaid
graph LR
    S1[Stream A: user clicks<br/>within 1-hour window] --> JOIN
    S2[Stream B: user purchases<br/>within 1-hour window] --> JOIN
    JOIN[State: buffer both streams<br/>Join on user_id within window] --> OUT[Matched pairs]
```

### Stream-Table Join (Enrichment)

```mermaid
graph LR
    S[Event stream: orders<br/>contains user_id] --> JOIN
    T[Database / KV store: user profiles<br/>loaded into stream processor state] --> JOIN
    JOIN[For each event: lookup user data] --> ENRICHED[Enriched orders]
```

### Table-Table Join (Materialized View Maintenance)

```mermaid
graph LR
    C1[CDC from users table] --> JOIN
    C2[CDC from orders table] --> JOIN
    JOIN[Maintain joined view<br/>in state store] --> MV[Materialized view:<br/>user + their orders]
```

---

## Limitations of Immutability

Event logs and immutable data have real practical constraints:

```mermaid
graph TD
    LIM[Limitations of Immutable Event Logs]
    LIM --> GDPR[GDPR Right to Erasure<br/>Cannot delete an event from an immutable log<br/>Solution: crypto-shredding — encrypt with per-user key, delete key]
    LIM --> HOT[Hot data fragmentation<br/>Updates = new version, old still there<br/>Storage grows; compaction needed]
    LIM --> PERF[Write-heavy workloads<br/>Not all data is naturally append-only<br/>e.g. user profile updates: 1000 edits → 1000 events]
    LIM --> RECALC[External dependencies<br/>Event processing must be deterministic<br/>Cannot re-fetch exchange rates at replay time]
    LIM --> ORDER[Total ordering required<br/>All consumers must see events in same order<br/>Hard to guarantee across distributed brokers]
```

**Compaction**: Kafka log compaction keeps only the latest value per key, removing all older versions. This allows indefinite retention of the "current state" snapshot without unbounded storage growth. Important for CDC use cases where Kafka is the system of record.

**Crypto-shredding** (for GDPR compliance): Encrypt each user's event data with a unique per-user encryption key. Store keys separately. When a user requests erasure, delete their key — all their events become undecipherable without changing the event log structure.

---

## Stream Processing Fault Tolerance

Unlike batch processing (rerun the whole job on failure), stream processing must handle failures while maintaining low latency:

```mermaid
graph LR
    subgraph "Checkpoint-Based Recovery (Flink)"
        SP[Stream Processor<br/>stateful operators]
        STATE[State: running aggregates]
        CKPT[Periodic checkpoint<br/>to durable storage]
        
        FAIL[Processor crashes]
        RESTORE[Restore from checkpoint<br/>Replay events since checkpoint]
        
        SP --> STATE
        STATE --> CKPT
        FAIL --> RESTORE
        RESTORE --> SP
    end
```

**Flink's checkpointing**: Periodically snapshot all operator state to durable storage (HDFS/S3). On failure, restore from checkpoint and replay input events from the saved offset. Recovery time = time since last checkpoint.

**Micro-batching** (Spark Structured Streaming): Process small batches (100ms) instead of truly continuous. Simpler fault tolerance (batch semantics), slightly higher latency.

**Exactly-once in stream processing**:
1. Store state and output offset atomically (same transaction)
2. Use idempotent sinks (deduplicate output at destination)
3. Kafka transactions: atomically commit both offset and output

**State backend options** (Flink):
- In-memory: fastest, bounded by heap size, lost on crash without checkpoint
- RocksDB: spills to disk, can handle TB of state, slightly slower
- Remote KV store: Redis, DynamoDB — higher latency, highly available

---

## Exactly-Once Semantics

```mermaid
graph TD
    AT_MOST[At-most-once<br/>May lose messages<br/>Easy to implement] 
    AT_LEAST[At-least-once<br/>May duplicate messages<br/>Standard default]
    EXACTLY[Exactly-once<br/>No loss, no duplicates<br/>Hard to implement]

    AT_LEAST -->|with idempotent consumers| EFFECTIVELY[Effectively-once<br/>Idempotent deduplication]
    AT_LEAST -->|with distributed transactions| EXACTLY
```

**Kafka exactly-once (EOS)**:
1. **Idempotent producer**: Each message has a sequence number. Broker deduplicates.
2. **Transactional API**: Read-process-write wrapped in Kafka transaction.
   Either all happen or none (atomically).
3. Limitation: Only works within Kafka. Writes to external systems (DB, API) require
   idempotent writes at the destination.
