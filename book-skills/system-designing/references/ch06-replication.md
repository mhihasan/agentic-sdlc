# Chapter 6: Replication

## Core Thesis
Replication keeps copies of data on multiple nodes. The hard part is handling changes to
replicated data. Every replication strategy makes a trade-off between consistency,
availability, and performance — and understanding these trade-offs is essential before
choosing a replication topology.

---

## Why Replicate?

```mermaid
graph TD
    REP[Replication] --> R1[Fault tolerance<br/>Survive node/disk failure]
    REP --> R2[Read throughput<br/>Multiple replicas serve reads]
    REP --> R3[Geo-proximity<br/>Replicas close to users]
    REP --> R4[Analytics isolation<br/>Read replicas for OLAP<br/>without impacting OLTP]
```

**Replication ≠ Backup**: Backups are point-in-time snapshots, not live copies. Replication
does not protect against accidentally deleting data — the deletion will be replicated.

---

## Single-Leader (Leader-Follower) Replication

```mermaid
graph TD
    W[Client Write] --> L[Leader<br/>Primary]
    L -->|Replication log| F1[Follower 1]
    L -->|Replication log| F2[Follower 2]
    L -->|Replication log| F3[Follower 3]
    R1[Client Read] --> F1
    R2[Client Read] --> F2
    R3[Client Read] --> L
```

**Properties**:
- All writes → leader only
- Reads → any replica (with consistency caveats)
- Replicas apply leader's log in same order

### Synchronous vs Asynchronous Replication

```mermaid
sequenceDiagram
    participant Client
    participant Leader
    participant Follower1 as Follower (sync)
    participant Follower2 as Follower (async)

    Client->>Leader: Write
    Leader->>Follower1: Replicate
    Follower1-->>Leader: ACK
    Leader->>Follower2: Replicate (no wait)
    Leader-->>Client: OK (after sync ACK)
    note over Follower2: Catches up eventually
```

| Mode | Durability | Write latency | Availability |
|------|-----------|--------------|-------------|
| Fully synchronous | Highest — no data loss | Highest — waits all followers | Lowest — one follower down = blocked |
| Semi-synchronous | High — 1 sync follower | Medium | Good — only 1 sync |
| Fully asynchronous | Lowest — leader crash = data loss | Lowest | Highest — writes always ack fast |

**Semi-synchronous** is the most common production setting: one follower is synchronous, the
rest are asynchronous. Ensures at least 2 copies (leader + 1 sync follower).

---

## Follower Setup and Failover

### Adding a New Follower

```mermaid
sequenceDiagram
    participant Leader
    participant Snapshot
    participant NewFollower

    NewFollower->>Leader: Request setup
    Leader->>Snapshot: Take consistent snapshot (no lock)
    Snapshot->>NewFollower: Copy snapshot
    NewFollower->>Leader: Catch up from WAL position of snapshot
    note over NewFollower: Now in sync — ready to serve reads
```

### Leader Failover

```mermaid
flowchart TD
    A[Leader becomes unreachable] --> B[Timeout exceeded?]
    B -->|No| A
    B -->|Yes| C[Elect new leader<br/>most up-to-date follower]
    C --> D[Reconfigure clients to new leader]
    D --> E[Old leader rejoins as follower]
    E --> F[Resolve any conflicts<br/>from diverged state]
```

**Failover hazards**:
1. **Data loss**: Async follower promoted → unreplicated writes lost
2. **Split-brain**: Two nodes think they're leader → write conflicts (use fencing tokens)
3. **Wrong timeout**: Too short → spurious failover under load. Too long → long recovery time.
4. **Primary key collisions**: If lost writes used auto-increment IDs, new leader's IDs may
   overlap with writes elsewhere (GitHub incident with MySQL → stale counter)

---

## Replication Lag Anomalies

These anomalies occur when reading from async followers:

### 1. Read-After-Write Inconsistency

```mermaid
sequenceDiagram
    participant User
    participant Leader
    participant Follower

    User->>Leader: Update profile photo
    Leader-->>User: OK
    User->>Follower: Read profile (page reload)
    Follower-->>User: Returns OLD photo (lag!)
```

**Solution — Read-your-own-writes consistency**:
- Read from leader for 1 minute after a write
- Track replication position; read from follower only if it's caught up
- Route user to same follower consistently (sticky sessions)

### 2. Monotonic Reads

```mermaid
sequenceDiagram
    participant User
    participant F1 as Follower1 (lag: 0s)
    participant F2 as Follower2 (lag: 5s)

    User->>F1: Read → sees new comment
    User->>F2: Refresh → sees OLD state (comment gone)
```

**Solution**: User always reads from same replica (session stickiness by user ID hash).

### 3. Consistent Prefix Reads

Order of causally related writes must be preserved:
```
Q: "How far into the future can you see?"   (write 1 to shard A)
A: "About ten seconds."                     (write 2 to shard B)

Reader sees shard B first → answer appears before question → nonsense
```

**Solution**: Causally related writes to same shard, or track causal dependencies.

---

## Multi-Leader Replication

```mermaid
graph LR
    subgraph "DC1 (US)"
        L1[Leader 1] --> F1a[Follower]
        F1a --> F1b[Follower]
    end
    subgraph "DC2 (EU)"
        L2[Leader 2] --> F2a[Follower]
    end

    L1 <-->|Async cross-DC replication| L2

    W1[Write] --> L1
    W2[Write] --> L2
```

**Use cases**:
- Multi-datacenter operation (writes local, replicate across DCs)
- Offline clients (mobile app as a "leader" when offline, syncs when online)
- Collaborative editing (Google Docs model)

### Write Conflicts

```mermaid
graph LR
    subgraph "Concurrent edits"
        C1[Client A: title = 'B'] --> L1[Leader 1]
        C2[Client B: title = 'C'] --> L2[Leader 2]
        L1 <-->|replicate| L2
        L1 --> CONF[CONFLICT!<br/>Which value wins?]
        L2 --> CONF
    end
```

**Conflict resolution strategies**:

| Strategy | Description | Risk |
|----------|-------------|------|
| Last-write-wins (LWW) | Higher timestamp wins | Data loss — concurrent writes may be lost |
| Merge | Application merges values | Complex, domain-specific |
| CRDT | Conflict-free Replicated Data Types | Limited data structures only |
| Custom logic | Application-defined conflict handler | Most flexible |

**LWW is the default in Cassandra and DynamoDB** — it silently discards concurrent writes.
This is acceptable only if losing some writes is acceptable.

---

## Leaderless Replication (Dynamo-Style)

```mermaid
graph TD
    W[Client Write<br/>w=3] --> N1[Node 1 ✅]
    W --> N2[Node 2 ✅]
    W --> N3[Node 3 ✅]
    W --> N4[Node 4 — DOWN]
    W --> N5[Node 5 ✅]

    note1[w=3: write to at least 3 of 5 nodes]

    R[Client Read<br/>r=3] --> N1
    R --> N2
    R --> N3
    note2[r=3: read from 3 nodes, take latest version]
```

**Quorum condition**: `w + r > n` (where n = total replicas) ensures overlap → always
reads at least one node that has the latest write.

For `n=5, w=3, r=3`: `3+3=6 > 5` ✅

**Read repair**: When reading, if different nodes return different values, the client writes
the newest value back to stale nodes.

**Anti-entropy**: Background process constantly compares replicas and fixes differences.

---

## Databases Backed by Object Storage

A newer architectural pattern: separate the storage engine from the storage medium.
Traditional databases own their storage (local disk or SAN). Cloud-native databases
store data in object storage (S3/GCS) and run compute separately.

```mermaid
graph LR
    subgraph "Traditional: compute + storage collocated"
        NODE[DB Node: CPU + RAM + Disk]
        DATA[All data on local disk]
        NODE --> DATA
    end

    subgraph "Object Storage-Backed DB"
        C1[Compute node 1]
        C2[Compute node 2]
        C3[Compute node 3 — ephemeral, auto-scaled]
        OBJ[Object Storage: S3 / GCS<br/>Actual data — cheap, durable, HA]
        C1 -->|reads/writes| OBJ
        C2 -->|reads/writes| OBJ
        C3 -->|reads/writes| OBJ
    end
```

**Examples**: Aurora (log-only over NVMe + S3), Neon (Postgres over S3), AlloyDB.

**Implications for replication**: Instead of shipping a replication log between nodes,
all nodes read from the same shared object storage. "Replication" is handled by the
object store's durability guarantees.

**Implications for follower setup**: No snapshot-and-catch-up needed — new compute nodes
simply start reading from object storage. Scale-out in seconds.

---

## Conflict Resolution in Multi-Leader Systems

When two leaders accept concurrent writes to the same key, a conflict must be resolved.

### Conflict Avoidance
Route all writes for a given record through the same leader:
```mermaid
graph LR
    U1[User A always → Leader 1]
    U2[User B always → Leader 2]
    note1[No conflict: each user's writes go to one leader<br/>Breaks down if leader fails or user moves region]
```
Most reliable: if the application can always route a user's writes to one leader, conflicts don't arise.

### Last-Write-Wins (LWW)
Attach a timestamp to each write; highest timestamp wins.
- ✅ Simple to implement
- ❌ Silent data loss: concurrent writes lose one value
- ❌ Clock skew means "last" is not deterministic

**Used by**: Cassandra (default), DynamoDB (if using LWW mode)

### CRDTs (Conflict-Free Replicated Data Types)
Data structures designed so concurrent updates can always be merged without conflict:

```mermaid
graph LR
    subgraph "G-Counter CRDT (grow-only)"
        N1["Node 1: {n1:5, n2:3}"] 
        N2["Node 2: {n1:4, n2:7}"]
        MERGE["Merge: {n1:max(5,4), n2:max(3,7)} = {n1:5, n2:7}"]
        TOTAL["Total = 5 + 7 = 12"]
        N1 --> MERGE
        N2 --> MERGE
        MERGE --> TOTAL
    end
```

**CRDT types**: G-Counter, PN-Counter, G-Set, OR-Set, LWW-Register, MV-Register.

**Used by**: Riak (CRDT-native), Redis (some data types), Collaborative editors (Yjs, Automerge).

**Limitation**: Only specific data structures fit the CRDT model. Arbitrary application logic
cannot be made conflict-free without redesigning data models.

### Sync Engines and Local-First Software

A newer pattern for collaborative applications (Figma, Linear, Notion):

```mermaid
graph LR
    subgraph "Local-First / Sync Engine"
        C1[Client A<br/>local copy of data<br/>offline capable]
        C2[Client B<br/>local copy of data]
        SE[Sync Engine<br/>Server-side]

        C1 -->|ops when online| SE
        C2 -->|ops when online| SE
        SE -->|merge + broadcast| C1
        SE -->|merge + broadcast| C2
        C1 -.->|works offline| C1
    end
```

- Each client maintains a full local copy (works offline)
- Operations are appended to a local log and synced when online
- The sync engine merges operations using CRDTs or operational transformation (OT)
- **Conflict resolution** is the core hard problem

**Examples**: Automerge, Yjs (CRDT-based), Google Docs (OT-based), Apple's CloudKit.

---

## Hinted Handoff (Leaderless Replication)

When a node is temporarily unavailable, another node accepts writes on its behalf,
storing them as "hints":

```mermaid
sequenceDiagram
    participant Client
    participant N1 as Node 1 (target — DOWN)
    participant N2 as Node 2 (hint holder)
    participant N3 as Node 3

    Client->>N2: Write (N1 is down)
    N2->>N2: Store hint: "this write belongs to N1"
    N2->>N3: Write
    note over N1: Node 1 recovers
    N2->>N1: Replay hint writes
    N1-->>N2: ACK
    N2->>N2: Delete hint
```

**Sloppy quorum**: Accept writes even when fewer than w nodes from the designated replica
set are available, by using other available nodes as hint holders.

**Risk**: Hinted handoff only improves write availability. Reads may still return stale data
until hints are replayed. Even with `w + r > n`, a sloppy quorum cannot guarantee reading
the most recent value.

---

## Detecting Concurrent Writes and Version Vectors

In leaderless replication, concurrent writes to the same key produce conflicting versions. The system must detect which writes are concurrent vs causally ordered.

### Concurrency, Time, and Relativity

Two operations are **concurrent** if neither knows about the other — not necessarily same wall-clock time. A and B are concurrent if A happened neither before nor after B in causal order.

```mermaid
graph LR
    A["Client 1: writes x=1 (unaware of x=2)"]
    B["Client 2: writes x=2 (unaware of x=1)"]
    C["Client 1: reads x=2, writes x=3 — causally after both"]
    A --> C
    B --> C
    note1[A and B are concurrent: conflict!<br/>C is causal successor of both: safe to keep only C]
```

### Version Vectors

Track a counter per replica to determine causal dominance:

```
V1 = {n1:3, n2:1}   V2 = {n1:2, n2:2}

V1 dominates V2 if ALL counters in V1 ≥ V2
Here: n1: 3>2 ✓  but  n2: 1<2 ✗
→ Neither dominates: CONCURRENT — keep both until merged

V3 = {n1:4, n2:2} dominates V1 and V2: n1:4≥3,2 ✓  n2:2≥1,2 ✓
→ V3 supersedes both safely
```

**Used by**: Riak, DynamoDB (internal), Git DAG, CRDTs.

### Monitoring Replication Staleness

```mermaid
graph LR
    L[Leader write offset: 1000]
    F1[Follower 1: offset 998 → lag 50ms]
    F2[Follower 2: offset 850 → lag 30s]
    ALERT[Alert if lag > SLA threshold]
```

**Operational metrics**: bytes lag (WAL offset delta) + time lag (seconds). Alert on time lag exceeding your read-your-own-writes SLA.

**Single-leader vs leaderless performance**: Single-leader: consistent reads from follower, write bottleneck at leader. Leaderless: writes to any node, tune `w` for throughput vs durability.

**Multi-region operation**: Cross-region replication RTT = 50–200ms. Async = low write latency, risk losing data on region failure. Sync = durability, high latency. Multi-leader per region = lowest latency, conflict resolution required.

---

## Replication Topologies

| Method | How | Trade-offs |
|--------|-----|-----------|
| Statement-based | Replicate SQL statements | ❌ Non-deterministic functions (NOW(), RAND()) |
| WAL shipping | Ship raw storage engine bytes | ❌ Tightly coupled to storage engine version |
| Row-based (logical) | Replicate changed rows | ✅ Storage-engine independent, most common |
| Trigger-based | Application-level triggers | ⚠️ High overhead, flexible but fragile |

**PostgreSQL WAL / MySQL binlog** = logical replication (row-based). This is what CDC tools
(Debezium) consume to create event streams.
