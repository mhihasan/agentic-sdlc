# Chapter 13: A Philosophy of Streaming Systems

## Core Thesis
Chapters 11 and 12 described batch and stream processing mechanics. This chapter asks:
what is the *right* way to architect a system around data flows? The answer is to treat
derived data — caches, indexes, ML models, search, analytics — as the output of continuous
transformations applied to a single stream of events. This "unbundled database" philosophy
leads to more evolvable, reliable, and maintainable systems.

---

## The Problem: Multiple Specialized Systems

```mermaid
graph TD
    APP[Application] -->|writes| PG[(PostgreSQL)]
    APP -->|writes| ES[(Elasticsearch)]
    APP -->|writes| RD[(Redis Cache)]
    APP -->|writes| DWH[(Data Warehouse)]

    PG -.->|out of sync?| ES
    PG -.->|out of sync?| RD
    PG -.->|out of sync?| DWH
    note1[Dual-write problem:<br/>Any write failure → inconsistency<br/>Race conditions between systems<br/>No single source of truth]
```

**The unbundled approach** — one event stream, many derived views:

```mermaid
graph TD
    APP2[Application] -->|one write| PG2[(PostgreSQL<br/>System of Record)]
    PG2 -->|CDC / WAL| KAFKA[Kafka<br/>Event log]
    KAFKA --> ES2[(Elasticsearch<br/>derived)]
    KAFKA --> RD2[(Redis Cache<br/>derived)]
    KAFKA --> DWH2[(Data Warehouse<br/>derived)]
    KAFKA --> ML[(ML Feature Store<br/>derived)]
    note2[Single source of truth<br/>All derived systems eventually consistent<br/>Can replay to rebuild any derived view]
```

---

## Derived Data and Total Ordering

```mermaid
graph LR
    subgraph "Ordering is easy at small scale"
        SINGLE[Single-node DB → total order<br/>Each write gets a sequential ID]
    end

    subgraph "Ordering is hard at global scale"
        MULTI[Multi-region / Multi-leader → no total order<br/>Events may be processed in different order<br/>in different datacenters]
        MULTI --> CAUSAL[Solution: Causal consistency<br/>Only order causally related events<br/>Let concurrent events be unordered]
    end
```

**Practical implication**: For most systems, causal consistency is sufficient. Total ordering
requires coordination (consensus) which is expensive. Only pay that cost when you need it.

---

## Lambda Architecture (Batch + Speed Layer)

```mermaid
graph LR
    INPUT[Input events] --> BATCH[Batch layer<br/>Recomputes everything periodically<br/>Accurate, high latency]
    INPUT --> SPEED[Speed layer<br/>Processes recent data<br/>Approximate, low latency]
    BATCH --> MERGE[Serving layer<br/>Merges batch + speed views]
    SPEED --> MERGE
    MERGE --> QUERY[Query]

    BATCH --> PROBLEM[Problems:<br/>Two codebases to maintain<br/>Batch result may differ from stream result<br/>Complex to operate]
```

**Kappa Architecture** (Nathan Marz's simplification):

```mermaid
graph LR
    INPUT2[Input events] --> STREAM[Stream processor only<br/>Flink / Spark Streaming]
    STREAM --> VIEW[Derived views / state]
    VIEW --> QUERY2[Query]

    REPLAY[Replay from Kafka offset 0<br/>→ rebuild any view] --> STREAM
    note1[One codebase. Batch = stream with full history replayed.<br/>Simpler to operate and reason about.]
```

---

## Unbundling Databases

The hypothesis: a distributed system can be built from composable primitives that
correspond to the internals of a monolithic database.

```mermaid
graph TD
    DB[Monolithic Database internals] --> UB[Unbundled equivalents]

    DB --> PK[Primary key index] --> UB_PK[Key-value store<br/>DynamoDB / Redis]
    DB --> SI[Secondary index] --> UB_SI[Search engine<br/>Elasticsearch]
    DB --> MV[Materialized views] --> UB_MV[Stream processor<br/>Kafka Streams / Flink]
    DB --> WR[Write-ahead log] --> UB_WR[Event log<br/>Kafka / Kinesis]
    DB --> QE[Query optimizer] --> UB_QE[Query engine<br/>Presto / Trino / BigQuery]
```

**Trade-off**:
- Integrated DB: Consistency, ACID, single tool, but limited scale per component
- Unbundled: Scale each component independently, but eventual consistency between components

---

## Designing Applications Around Dataflow

```mermaid
graph LR
    subgraph "Request-Response Model (traditional)"
        C1[Client] -->|HTTP request| SVC[Service]
        SVC -->|query| DB3[(DB)]
        DB3 -->|result| SVC
        SVC -->|HTTP response| C1
    end

    subgraph "Dataflow Model"
        C2[Client] -->|subscribe to state changes| STREAM2[Event stream]
        STREAM2 -->|push updates| C2
        note2[Server pushes state changes<br/>Client reactively updates<br/>Lower latency, reduced polling]
    end
```

### Application Code as Derivation

```mermaid
graph LR
    EVENTS3[Event log: raw user actions] 
    EVENTS3 -->|derivation function: ML model| SCORE[Recommendation scores<br/>derived view]
    EVENTS3 -->|derivation function: aggregation| METRICS[Usage metrics<br/>derived view]
    EVENTS3 -->|derivation function: join + filter| FEED[User feed<br/>derived view]
    
    note1[When underlying events change → re-run derivation<br/>Derived views are not special — they're just functions of the log]
```

**CQRS (Command Query Responsibility Segregation)**:

```mermaid
graph LR
    WRITE[Write side: Commands → Events → Event log]
    READ[Read side: Subscribe to events → maintain optimized read model]
    WRITE -->|event log| READ
    note1[Write path optimized for transactional writes<br/>Read path optimized for each query pattern<br/>Independently scalable]
```

---

## End-to-End Correctness

The hardest problems occur at system boundaries — not within a single component.

```mermaid
graph LR
    U[User clicks Buy] --> APP[App]
    APP -->|write to DB| DB4[(DB)]
    APP -->|send to Kafka| KF[Kafka]
    KF --> PAY[Payment service]
    PAY -->|charge card| CC[Payment gateway]
    CC -->|callback| PAY
    PAY -->|write result| DB5[(DB)]

    FAIL[Network failure anywhere in this chain:<br/>Did the charge happen or not?<br/>Was the order saved?]
```

**Idempotency as the solution**:
- Every operation must be safe to retry
- Each step must be identified by a unique operation ID
- Upstream systems track which IDs they've processed

```python
# Idempotent payment processing
def process_payment(order_id: str, amount: Decimal) -> None:
    if already_processed(order_id):  # check idempotency key
        return  # safe to call multiple times
    
    charge_card(amount)
    mark_processed(order_id)  # atomic with the charge via outbox pattern
```

---

## Aiming for Correctness

Even with perfectly designed individual components, bugs occur at the boundaries.
The end-to-end correctness question: is the system correct, not just each component?

### The End-to-End Argument

A principle from network systems: reliability functions implemented at a lower layer
can only be fully guaranteed if also implemented at the higher (application) layer.

```mermaid
graph LR
    subgraph "Example: Payment Processing"
        CLIENT[Client] -->|POST /charge| APP[App Server]
        APP -->|INSERT payment| DB[(DB)]
        APP -->|charge_card()| GATEWAY[Payment Gateway]
        
        FAIL1[Network drop between APP and CLIENT<br/>Client retries → second charge!]
        FAIL2[App crashes after DB insert but before gateway call<br/>DB has payment, gateway doesn't]
    end

    subgraph "End-to-End Solution"
        IDEM[Idempotency key in every request<br/>App generates UUID per operation<br/>Gateway deduplicates by key]
    end
```

**The lesson**: The transport layer (TCP) guarantees at-most-once delivery between hops.
But end-to-end, across service boundaries, restarts, and retries — the application must
enforce exactly-once semantics itself via idempotency keys.

### Duplicate Suppression

```mermaid
sequenceDiagram
    participant Client
    participant App
    participant DB

    Client->>App: POST /transfer {amount:100, idempotency_key: "abc-123"}
    App->>DB: BEGIN
    App->>DB: INSERT INTO requests(key="abc-123") ON CONFLICT DO NOTHING
    App->>DB: UPDATE balances ...
    App->>DB: COMMIT
    App-->>Client: 200 OK

    note over Client: Network timeout — client retries
    Client->>App: POST /transfer {amount:100, idempotency_key: "abc-123"}
    App->>DB: BEGIN
    App->>DB: INSERT INTO requests(key="abc-123") ON CONFLICT DO NOTHING → 0 rows
    App->>DB: ROLLBACK (already done)
    App-->>Client: 200 OK (idempotent — same result)
```

**Implementation**: The `requests` table has a unique constraint on `idempotency_key`.
The INSERT + operation happen in one atomic transaction. Second attempt sees the key
already exists → knows it's a duplicate → returns the original result.

---

## Timeliness vs Integrity

Two distinct correctness properties that are often conflated:

```mermaid
graph LR
    subgraph "Timeliness"
        T[Users see up-to-date state<br/>Read-your-own-writes<br/>Monotonic reads]
        T --> VIOL[Violations: stale reads<br/>User sees old data briefly]
        VIOL --> TOLERATE[Usually tolerable:<br/>a few seconds of staleness<br/>is rarely a problem]
    end

    subgraph "Integrity"
        I[No data corruption or loss<br/>Committed data stays committed<br/>No duplicate charges, no lost orders]
        I --> VIOL2[Violations: permanent data corruption<br/>Duplicate charges, lost messages]
        VIOL2 --> INTOLERABLE[NEVER acceptable:<br/>the system is fundamentally broken]
    end
```

**The key insight**: Systems can sacrifice timeliness (eventual consistency) without
compromising integrity, if they use idempotency and end-to-end exactly-once semantics.

**Ordering**: Integrity is a stronger requirement than timeliness. Systems that sacrifice
integrity to gain availability are dangerous. Systems that sacrifice timeliness are just
eventually consistent.

---

## Enforcing Constraints in an Unbundled System

Without distributed transactions, how do you enforce unique constraints (e.g., unique usernames)?

```mermaid
graph LR
    subgraph "Serializable DB: trivial"
        DB1[(DB)] -->|INSERT username UNIQUE constraint| OK[Either succeeds or unique violation]
    end

    subgraph "Distributed system: hard"
        W1[Write: username=alice → shard A]
        W2[Write: username=alice → shard B]
        W1 & W2 -->|concurrent| DUPE[Both succeed — duplicate username!]
    end

    subgraph "Solution: Route all writes for a constraint through one partition"
        ALL[All username writes → username shard<br/>Shard enforces uniqueness locally]
    end
```

**Two-phase approach for complex constraints**:
1. Write tentatively with a request ID
2. Asynchronous validation: check the constraint
3. If violated: mark tentative write as rejected, notify client

This trades timeliness (constraint enforcement may be slightly delayed) for integrity
(eventually, no violations survive).

---

## Trust, but Verify

Even correct-looking systems can have silent data corruption bugs. The solution: don't just assume correctness — actively verify it.

```mermaid
graph LR
    subgraph "Passive trust (fragile)"
        WRITE[Write data] --> READ[Read data]
        READ --> ASSUME[Assume it's correct]
        note1[Disk corruption, bit rot, hardware bugs,<br/>software bugs, encoding errors —<br/>all can silently corrupt data]
    end

    subgraph "Active verification (robust)"
        W2[Write data + checksum] --> R2[Read data + verify checksum]
        R2 -->|mismatch| ALARM[Raise alarm, use replica]
        R2 -->|match| OK[Trust output]
        
        AUDIT[Periodic audit job<br/>Cross-check derived data against source]
    end
```

**Techniques**:
- **Checksums**: Store a hash with every record. Verify on read. Detects bit rot and disk corruption.
- **Audit logs**: Periodically recompute derived data from source and compare. Detects bugs in derivation logic.
- **End-to-end checksums**: Include a checksum computed at the data source all the way through the pipeline to the final consumer. Detects corruption at any intermediate step.
- **Write-audit-read**: After writing, read back and verify. Detects write failures that were not properly reported.

**The Parable of Financial Reconciliation**: Banks routinely run reconciliation jobs that cross-check ledger balances against transaction histories, interbank settlement records, and account statements. This is "trust but verify" at industrial scale — not because individual transactions are untrustworthy, but because the cumulative effect of silent errors is catastrophic.

**Why this matters for data pipelines**: ETL pipelines move data through many systems. Errors compound. A 0.001% error rate is invisible in daily monitoring but produces significant corruption over months of data.

**Practical checklist**:
```python
# After every significant pipeline step
assert output_record_count == expected_count
assert output_sum == source_sum  # financial reconciliation
assert sample_records_match_source()  # spot-check
assert no_nulls_in_required_fields()
assert referential_integrity_holds()
```

---

## The Dataflow Philosophy: Summary

```mermaid
graph TD
    T1[Immutable event log<br/>is the source of truth] -->|derived| T2[Mutable state<br/>is a cache of the log]
    T2 -->|can always be| T3[Rebuilt by replaying the log]
    
    T4[No distributed transactions<br/>between components] -->|instead| T5[Idempotent writes<br/>+ end-to-end deduplication]
    
    T6[Synchronous request-response] -->|evolve toward| T7[Async event-driven dataflow<br/>for better availability + decoupling]
```

**When to apply this philosophy**:
- Systems with multiple specialized data stores that must stay in sync
- High-write systems where keeping all stores consistent synchronously is a bottleneck
- Systems that need auditability, replay, or temporal queries
- Analytics alongside OLTP without interference

**When NOT to use**:
- Simple CRUD applications with a single DB — complexity not justified
- Systems with hard real-time consistency requirements between all components (use 2PC or saga)
