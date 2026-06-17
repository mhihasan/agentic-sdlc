# Chapter 8: Transactions

## Core Thesis
Transactions are an abstraction layer that hides a complex set of concurrency and fault
tolerance problems behind a simple "all-or-nothing" guarantee. Understanding isolation
levels — what guarantees they provide and what anomalies they still allow — is essential
for any engineer working with databases at scale.

---

## ACID — What It Actually Means

```mermaid
graph TD
    ACID --> A[Atomicity<br/>All writes succeed or all are rolled back<br/>NOT about concurrency]
    ACID --> C[Consistency<br/>Application-defined invariants hold<br/>DB can only help — app must enforce]
    ACID --> I[Isolation<br/>Concurrent transactions appear serial<br/>THIS is the hard part]
    ACID --> D[Durability<br/>Committed data survives crashes<br/>WAL + replication]
```

**Common misconception**: The C in ACID is not a database property — it's an application
property. The database provides atomicity and isolation; you define the consistency rules.

**BASE** (Basically Available, Soft state, Eventual consistency) — the alternative to ACID
for systems that sacrifice isolation for availability/performance.

---

## Isolation Levels — The Core Trade-off

Higher isolation → fewer anomalies → more lock contention → worse performance.

```mermaid
graph LR
    subgraph "Anomalies"
        A1[Dirty Reads]
        A2[Non-Repeatable Reads]
        A3[Phantom Reads]
        A4[Lost Updates]
        A5[Write Skew]
        A6[Phantom Write Skew]
    end

    subgraph "Isolation Levels"
        L1[Read Uncommitted]
        L2[Read Committed]
        L3[Repeatable Read / Snapshot Isolation]
        L4[Serializable]
    end

    L1 -.->|prevents none| A1
    L2 -->|prevents| A1
    L3 -->|prevents| A1
    L3 -->|prevents| A2
    L3 -.->|does NOT prevent| A4
    L3 -.->|does NOT prevent| A5
    L4 -->|prevents all| A1
    L4 -->|prevents all| A2
    L4 -->|prevents all| A3
    L4 -->|prevents all| A4
    L4 -->|prevents all| A5
    L4 -->|prevents all| A6
```

---

## Read Committed (Default in PostgreSQL, Oracle, SQL Server)

**Guarantees**:
- No dirty reads: only read data that has been committed
- No dirty writes: only overwrite data that has been committed

```mermaid
sequenceDiagram
    participant T1
    participant DB
    participant T2

    T1->>DB: UPDATE balance = 500 (not committed)
    T2->>DB: SELECT balance
    DB-->>T2: Returns OLD value (read committed prevents dirty read)
    T1->>DB: COMMIT
    T2->>DB: SELECT balance
    DB-->>T2: Returns 500 (now committed)
```

**Implementation**: For each object, DB keeps both the old committed value and the new
uncommitted value. Reads get the old value until commit.

**What Read Committed does NOT prevent**: Non-repeatable reads (value changes between two
reads in same transaction), lost updates, write skew.

---

## Snapshot Isolation (Repeatable Read)

**Key mechanism**: MVCC (Multi-Version Concurrency Control)

```mermaid
graph TD
    subgraph "MVCC — Multiple versions per row"
        V1["txn_id=1: balance=500<br/>(committed)"]
        V2["txn_id=12: balance=600<br/>(committed)"]
        V3["txn_id=25: balance=300<br/>(in progress)"]
    end

    T10["Transaction T10 (started when latest_committed=20)"]
    T10 -->|sees| V2
    T10 -->|does NOT see| V3

    T30["Transaction T30 (started when latest_committed=30)"]
    T30 -->|sees| V3
```

**Visibility rule**: A row version is visible to transaction T if:
1. The writing transaction committed before T started
2. The writing transaction is not T itself

**Benefits**:
- Readers never block writers, writers never block readers
- Long-running analytics queries don't interfere with OLTP
- Consistent database backup without locking

**Naming confusion**: PostgreSQL calls this "Repeatable Read"; Oracle calls it "Serializable"
(misleadingly). True Serializable is stronger than Snapshot Isolation.

---

## Preventing Lost Updates

Lost update = two transactions read-modify-write concurrently; one overwrites the other.

```mermaid
sequenceDiagram
    participant T1
    participant DB
    participant T2

    T1->>DB: Read counter = 42
    T2->>DB: Read counter = 42
    T1->>DB: Write counter = 43
    T2->>DB: Write counter = 43  ← LOST UPDATE: T1's increment lost
```

**Solutions**:

| Solution | How | When |
|----------|-----|------|
| Atomic operations | `UPDATE counter SET val = val + 1` | Simple increment/decrement |
| Explicit locking | `SELECT ... FOR UPDATE` | Complex read-modify-write in app code |
| Automatic detection | DB detects and retries (PostgreSQL, MySQL) | General purpose |
| Compare-and-swap | `UPDATE ... WHERE val = old_val` | Optimistic, no DB support needed |

---

## Write Skew and Phantoms

**Write skew**: Two transactions read overlapping data, then each writes based on what they
read — but combined result violates an invariant that each individual write would have honored.

```
Example: On-call doctor scheduling
Rule: At least 1 doctor must be on call at all times
Doctor A: SELECT count(*) FROM oncall → 2. "I can go off call"
Doctor B: SELECT count(*) → 2. "I can go off call"
Both update themselves as off-call → 0 doctors on call → INVARIANT VIOLATED
```

```mermaid
sequenceDiagram
    participant Alice
    participant Bob
    participant DB

    Alice->>DB: SELECT count(*) → 2 doctors on call
    Bob->>DB: SELECT count(*) → 2 doctors on call
    Alice->>DB: UPDATE alice SET oncall=false
    Bob->>DB: UPDATE bob SET oncall=false
    note over DB: 0 doctors on call — invariant violated
```

**Write skew requires Serializable isolation to prevent.**

**Phantom**: A write in one transaction changes the result set of a search query in another
transaction. Write skew where the read query doesn't match the row being written.

---

## Serializable Isolation — Implementations

### 1. Serial Execution (VoltDB, Redis, FoundationDB)

Execute transactions one at a time, on a single thread:
- Works when transactions are short and dataset fits in RAM
- Stored procedures (not interactive multi-round-trip transactions)

### 2. Two-Phase Locking (2PL)

```mermaid
graph LR
    subgraph "2PL Protocol"
        GR[Growing phase<br/>Acquire locks] --> LK[Hold all locks]
        LK --> SR[Shrinking phase<br/>Release locks at commit/abort]
    end

    subgraph "Lock types"
        SH[Shared lock<br/>for reads — many allowed]
        EX[Exclusive lock<br/>for writes — one at a time]
        SH -.->|blocks| EX
        EX -.->|blocks| SH
        EX -.->|blocks| EX2[another EX]
    end
```

**Predicate locks**: Lock all rows matching a WHERE clause (not just rows that exist yet).
Prevents phantoms. Expensive — often replaced with index-range locks.

**Deadlock**: T1 holds lock A, waits for B; T2 holds B, waits for A.
Database detects and aborts one transaction.

### 3. Serializable Snapshot Isolation (SSI) — PostgreSQL default "Serializable"

Optimistic approach:
1. Execute using snapshot isolation (no blocking)
2. Track reads and writes
3. At commit: detect if any snapshot assumption was violated
4. If violated: abort and retry

```mermaid
graph LR
    T1[T1 reads X, writes Y] --> COMMIT
    T2[T2 reads Y, writes X] --> COMMIT
    COMMIT --> DETECT[Detect: T1 read X before T2 wrote it<br/>T2 read Y before T1 wrote it → cycle!]
    DETECT --> ABORT[Abort one transaction]
```

**SSI vs 2PL**:
- SSI: Optimistic, high throughput, retry on conflict
- 2PL: Pessimistic, lower throughput, blocks on conflict

---

## Distributed Transactions and Two-Phase Commit (2PC)

```mermaid
sequenceDiagram
    participant App
    participant Coord as Coordinator
    participant DB1 as Participant 1
    participant DB2 as Participant 2

    App->>Coord: Begin distributed txn
    Coord->>DB1: Prepare (phase 1)
    Coord->>DB2: Prepare (phase 1)
    DB1-->>Coord: Yes (voted commit)
    DB2-->>Coord: Yes (voted commit)
    Coord->>DB1: Commit (phase 2)
    Coord->>DB2: Commit (phase 2)
    DB1-->>Coord: Done
    DB2-->>Coord: Done
```

**The problem with 2PC**:
- If coordinator crashes after receiving "Yes" votes but before sending "Commit": participants
  are stuck in "prepared" state — locks held indefinitely ("in-doubt transaction")
- Coordinator is a single point of failure
- Blocking protocol — cannot progress without coordinator

**2PC usage in practice**: XA transactions (Java EE, MSDTC). Performance penalty 10–100× vs
single-node. Most cloud-native architectures avoid 2PC and use sagas or eventual consistency instead.

---

## Saga Pattern (Alternative to 2PC)

```mermaid
graph LR
    S1[Step 1: Reserve inventory] -->|success| S2[Step 2: Charge payment]
    S2 -->|success| S3[Step 3: Update order status]
    S3 -->|fail| C3[Compensate: Revert order status]
    C3 --> C2[Compensate: Refund payment]
    C2 --> C1[Compensate: Release inventory]
```

- Each step is a local transaction with a compensating transaction for rollback
- No distributed locks — steps are independent
- Eventually consistent — a window where partial state exists
- Complex: must design compensating transactions for every step

---

## What Exactly Is a Transaction?

**DDIA's working definition**: A transaction is a way for an application to group several
reads and writes together into a logical unit. Either the entire transaction succeeds
(commit) or it fails (abort, rollback), and the application can retry safely.

```mermaid
graph LR
    subgraph "Without transactions"
        W1[Write A] --> FAIL[System crash]
        FAIL --> PARTIAL[Partial state: A written, B not written]
        PARTIAL --> CORRUPT[Inconsistent state — permanent]
    end

    subgraph "With transactions"
        T[BEGIN]
        T --> WA[Write A]
        WA --> WB[Write B]
        WB --> COMMIT{Commit?}
        COMMIT -->|crash before commit| ROLLBACK[Rollback: A + B undone]
        COMMIT -->|success| DONE[Both A and B committed]
    end
```

**Not all applications need transactions**: Systems that handle only one operation at a
time on a single object (e.g., simple key-value stores), or systems that tolerate
partial failures and eventual consistency, can avoid transaction overhead.

---

## Materializing Conflicts (Preventing Phantoms with Locks)

Write skew involves a phantom: the transaction's WHERE clause reads rows that don't
yet exist when the lock needs to be taken. Predicate locks prevent phantoms, but
are expensive. Materializing conflicts creates concrete rows to lock.

```mermaid
graph LR
    subgraph "Write Skew: Meeting Room Booking"
        T1[T1: Is room 123 free 2-3pm? → yes]
        T2[T2: Is room 123 free 2-3pm? → yes]
        T1 --> I1[INSERT booking(room=123, 2-3pm)]
        T2 --> I2[INSERT booking(room=123, 2-3pm)]
        I1 & I2 --> DOUBLE[Double booking! — phantom write skew]
    end

    subgraph "Materialized Conflicts Solution"
        PRE[Pre-populate all possible<br/>room × time-slot rows]
        LOCK["SELECT ... FOR UPDATE<br/>on room=123, time=2-3pm row"]
        LOCK --> ONE[Only one transaction wins the lock]
        note1[Now there is a real row to lock<br/>Phantom becomes a regular dirty write conflict]
    end
```

**Materializing conflicts** = creating a row for every possible combination that could
conflict, so that the DB can use row-level locking instead of predicate locking.

**Drawback**: Leaks concurrency-control mechanism into the data model. Only use as a last
resort if SSI or explicit locking isn't available.

---

## Actual Serial Execution

The simplest way to achieve serializability: only one transaction at a time, on a single thread.

```mermaid
graph TD
    T1[Transaction 1] -->|queue| CORE[Single-threaded executor]
    T2[Transaction 2] -->|queue| CORE
    T3[Transaction 3] -->|queue| CORE
    CORE -->|execute one at a time| DB[In-memory DB]

    note1[Why is this feasible now?<br/>RAM is cheap enough for working dataset<br/>Single thread eliminates all lock contention<br/>No overhead from coordination]
```

**Requirements for serial execution**:
1. Dataset must fit in RAM (or at least working set)
2. Transactions must be short — no interactive multi-round-trip transactions
3. Use stored procedures: send the entire transaction logic to the DB upfront
4. Cross-partition transactions are expensive — route to one partition when possible

**Examples**: VoltDB, SingleStore, Redis (single-threaded command execution), FoundationDB.

**Throughput**: A single core can process ~100K simple transactions/second. For many
workloads, this is sufficient and eliminates all concurrency bugs.

---

## Three-Phase Commit (3PC) and Its Limits

3PC attempts to fix 2PC's blocking problem by adding a third phase:

```mermaid
sequenceDiagram
    participant Coord as Coordinator
    participant P1 as Participant
    Phase1: CanCommit? → YES/NO
    Phase2: PreCommit (write to stable storage, send ACK)  
    Phase3: DoCommit (actually commit)
    
    note over Coord,P1: If coordinator crashes after PreCommit:<br/>Participants can commit without coordinator<br/>if a new coordinator takes over
```

**Why 3PC is not used in practice**: It requires a perfectly synchronous network with bounded delays. In real networks with arbitrary message delays, 3PC can still block or make incorrect decisions. It's theoretically elegant but practically fragile. The industry uses 2PC despite its flaws, combined with manual intervention for stuck transactions.

---

## Distributed Transactions Across Different Systems (Heterogeneous Transactions)

When a transaction spans different types of systems (e.g., a database AND a message queue), 2PC requires all participants to support the XA protocol:

```mermaid
graph LR
    APP[Application]
    APP -->|XA begin| DB[(PostgreSQL)]
    APP -->|XA begin| MQ[ActiveMQ / RabbitMQ]
    APP -->|XA begin| DB2[(MySQL)]
    
    APP -->|XA prepare| ALL
    ALL -->|all yes| APP
    APP -->|XA commit| ALL
    
    note1[XA = eXtended Architecture (X/Open standard)<br/>Supported by Java EE, MSDTC<br/>10-100× slower than single-system transactions<br/>Coordinator is a SPOF]
```

**Database-internal distributed transactions**: When all participants are nodes of the same database system (e.g., CockroachDB or Spanner), the vendor can use a custom protocol optimized for their system. Far more efficient than XA — same atomicity guarantees without the XA coordination overhead.

**Exactly-Once Message Processing across DB + Queue**:

```mermaid
graph LR
    MSG[Kafka message: order_placed] --> PROC[Stream processor]
    PROC -->|write result| DB3[(Database)]
    PROC -->|ack offset| KAFKA2[Kafka]
    
    FAIL[Crash between DB write and Kafka ack]
    FAIL --> REPLAY[Message replayed: duplicate processing]
    
    SOL[Solution: idempotent writes<br/>Use message offset as idempotency key<br/>DB write is conditional: INSERT ... IF NOT EXISTS]
```

**Kafka Transactions** (EOS): Kafka's transactional API atomically commits both the consumer offset advance AND the producer's output messages. This creates exactly-once semantics entirely within Kafka — no XA needed.

---

## Serializable Snapshot Isolation (SSI) — Deep Dive

SSI (PostgreSQL's "Serializable" level) tracks read/write dependencies to detect conflicts:

```mermaid
graph LR
    T1[T1: reads table A, writes table B]
    T2[T2: reads table B, writes table A]
    
    DEP1[T1 reads A before T2 writes A]
    DEP2[T2 reads B before T1 writes B]
    
    CYCLE[Dependency cycle detected → abort one transaction]
    DEP1 --> CYCLE
    DEP2 --> CYCLE
    
    note1[This is the on-call doctor write skew scenario<br/>SSI detects it without blocking]
```

**Detection of stale MVCC reads**: T1 reads a snapshot; later T2 modifies the data T1 read and commits. At T1's commit time, SSI checks: "did anything I read get modified by a committed transaction?" If yes, and there's a dangerous pattern → abort T1.

**SSI vs 2PL trade-off**:
- 2PL: blocking, high contention → good for write-heavy, conflict-heavy workloads
- SSI: optimistic, non-blocking → good for read-heavy workloads with rare conflicts
- Both provide full serializability

**Two-Phase Locking — Predicate and Index-Range Locks**:
- **Predicate lock**: locks all rows matching a WHERE clause, including rows that don't exist yet (prevents phantoms)
- **Index-range lock**: approximate predicate lock on an index range (e.g., lock all rows with `shift_id = 1234` via the index). Less precise but cheaper — locks a superset of matching rows

---

## Isolation Level Quick Reference

| Level | Dirty Read | Non-Repeatable Read | Phantom | Lost Update | Write Skew |
|-------|-----------|--------------------|---------|-----------| ----------|
| Read Uncommitted | ❌ | ❌ | ❌ | ❌ | ❌ |
| Read Committed | ✅ | ❌ | ❌ | ❌ | ❌ |
| Repeatable Read / SI | ✅ | ✅ | ❌ | Partial | ❌ |
| Serializable | ✅ | ✅ | ✅ | ✅ | ✅ |

✅ = prevented, ❌ = NOT prevented
