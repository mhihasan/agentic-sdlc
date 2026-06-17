# Chapter 10: Consistency and Consensus

## Core Thesis
Chapter 9 established that distributed systems are unreliable. This chapter asks: what
correctness guarantees *can* we achieve, and at what cost? Linearizability, total order
broadcast, and consensus are the strongest guarantees — and understanding their
relationships is the foundation of distributed systems reasoning.

---

## The Consistency Spectrum

```mermaid
graph LR
    WEAK[Eventual Consistency<br/>Replicas converge eventually<br/>— no ordering guarantees] -->
    CAUSAL[Causal Consistency<br/>Causally related ops ordered<br/>— concurrent ops unordered] -->
    SI[Snapshot Isolation<br/>Each txn sees consistent snapshot<br/>— not necessarily latest] -->
    LIN[Linearizability<br/>Behaves like single copy<br/>— strongest, most expensive]
```

---

## Linearizability

**Definition**: The system appears to have a single copy of the data, and all operations
on it are atomic. Once a write completes, all subsequent reads see that value.

```mermaid
sequenceDiagram
    participant Alice
    participant DB
    participant Bob

    Alice->>DB: Write X = new_value
    DB-->>Alice: OK (write complete)
    Bob->>DB: Read X
    DB-->>Bob: MUST return new_value (linearizable)
    note over DB: If write is complete, every subsequent read anywhere must see it
```

**Non-linearizable example**:
```
Alice: Read X → "old"
Alice: Read X again (same request) → "new"   ← OK, value changed
Bob:  Read X → "old"    ← NOT OK if Alice already saw "new"
```

If Alice saw "new" and Bob sees "old" after that, the system is not linearizable.

### When Linearizability Is Required

| Use Case | Why |
|----------|-----|
| Leader election / distributed locks | Only one node must win |
| Unique constraint enforcement | Usernames, email addresses must be globally unique |
| Cross-channel coordination | Image upload → thumbnail service must see complete image |
| Distributed counters / ID generation | Must not issue duplicate IDs |

### Linearizability vs Serializability

| Concept | About | Applies to |
|---------|-------|-----------|
| Linearizability | Recency of individual reads/writes | Single-object operations |
| Serializability | Isolation between transactions | Multi-object transactions |

A system can be serializable but not linearizable (snapshot isolation).
A system can be linearizable but not serializable.
**Strict serializability** = both: serializable AND linearizable.

---

## The CAP Theorem — and Why It's Unhelpful

```mermaid
graph TD
    CAP[CAP Theorem: Pick 2 of 3]
    CAP --> C[Consistency<br/>= Linearizability]
    CAP --> A[Availability<br/>= Every request gets a response]
    CAP --> P[Partition tolerance<br/>= System works despite network splits]

    note1[Network partitions are not optional!<br/>They happen in any real system]
    note1 --> REAL[Real choice: CP or AP<br/>During a network partition]
```

**Why CAP is misleading**:
1. "Availability" in CAP ≠ high availability in practice
2. Network partitions are inevitable — you don't choose to tolerate them
3. CAP only applies during a network partition — ignores latency, the more common issue
4. Many nuances between "consistent" and "available" that CAP doesn't capture

**Kleppmann's framing**: The real trade-off is **consistency vs latency** (PACELC):
- Under normal operation: choose between lower latency or stronger consistency
- Under partition: choose between availability or consistency

---

## Implementing Linearizable Systems

```mermaid
graph TD
    SINGLE[Single-Leader Replication<br/>Read from leader only] --> LIN_MAYBE[Linearizable IF no bugs<br/>in failover / clock handling]
    CONSENSUS[Consensus algorithms<br/>Raft, Paxos, Zab] --> LIN_YES[Linearizable writes + reads<br/>via quorum]
    MULTI[Multi-Leader Replication] --> NOT_LIN[❌ Not linearizable<br/>concurrent writes, no total order]
    LEADERLESS[Leaderless / Dynamo-style] --> DEPENDS[Depends on quorum settings<br/>Even w+r>n: not strictly linearizable<br/>due to concurrent writes + sloppy quorum]
```

---

## The Cost of Linearizability: CAP in Practice

```mermaid
sequenceDiagram
    participant DC1 as Datacenter 1
    participant DC2 as Datacenter 2
    participant Net as Network (partitioned)

    DC1->>Net: Replicate write
    Net->>DC2: (blocked by partition)
    note over DC2: Options during partition:
    DC2->>Client: Return stale data (available, not linearizable) → AP
    DC2->>Client: Return error (consistent, not available) → CP
```

Single-datacenter databases (Raft) choose CP — refuse to serve if can't reach majority.
Multi-region with async replication chooses AP — serve locally, may be stale.

---

## Logical Clocks and Ordering

When linearizability is too expensive, logical clocks provide causal ordering:

### Lamport Timestamps

```mermaid
graph LR
    E1["Event A: t=1, node=1"]
    E2["Event B: t=2, node=1<br/>(caused by A)"]
    E3["Event C: t=1, node=2<br/>(concurrent with A)"]
    E4["Event D: t=3, node=2<br/>(receives message from B, t=max(2,1)+1=3)"]

    E1 --> E2
    E2 -->|message| E4
    E3 --> E4
```

**Lamport timestamp**: `t = max(my_clock, received_clock) + 1`

**Limitation**: Can determine causal ordering, but cannot detect concurrent events. If
`t(A) < t(B)`, either A caused B, or A happened concurrently with B (and got a lower number
by coincidence).

### Vector Clocks

```mermaid
graph LR
    A["VC: [A:1, B:0, C:0]"] --> B["VC: [A:2, B:0, C:0]"]
    C["VC: [A:0, B:1, C:0]"] --> D["receives A's message<br/>VC: [A:2, B:2, C:0]"]
    B -->|message| D
```

**Vector clocks** detect concurrent events: if neither VC dominates the other, events are concurrent.
Used in: Amazon Dynamo, Riak, CRDTs.

---

## Consensus

**Consensus problem**: Multiple nodes agree on a single value. Required for:
- Leader election
- Atomic commit (2PC is not consensus — see Ch.8)
- Total order broadcast

### Why Consensus Is Hard: FLP Impossibility

In an asynchronous system (Ch.9 definition), there is no algorithm that:
1. Always terminates
2. Always agrees
3. Is valid (agreed value was proposed by some node)

In practice: algorithms can terminate in partially synchronous conditions (network is usually bounded).

### Raft and Paxos

```mermaid
sequenceDiagram
    participant L as Leader
    participant F1 as Follower 1
    participant F2 as Follower 2

    note over L,F2: Phase 1: Leader election (term 5)
    L->>F1: RequestVote (term=5)
    L->>F2: RequestVote (term=5)
    F1-->>L: VoteGranted
    F2-->>L: VoteGranted
    note over L,F2: Phase 2: Log replication
    L->>F1: AppendEntries (index=42, value=X)
    L->>F2: AppendEntries (index=42, value=X)
    F1-->>L: ACK
    F2-->>L: ACK
    note over L: Majority (2/2) → commit entry 42
    L->>F1: Commit
    L->>F2: Commit
```

**Raft guarantees**:
- At most one leader per term
- A log entry is committed only when stored on a majority of nodes
- Committed entries are never deleted

**ZooKeeper** uses ZAB (similar to Raft/Paxos) and exposes: linearizable writes, ordered
updates, watches (event notifications). Used for distributed coordination, not for application data.

---

## Total Order Broadcast

**Definition**: All nodes deliver messages in the same order. No message is delivered to
some nodes but not others.

```mermaid
graph TD
    TOB[Total Order Broadcast] --> USE1[Database replication<br/>All replicas apply writes in same order]
    TOB --> USE2[Serializable transactions<br/>Execute in same order = serializable]
    TOB --> USE3[Unique ID generation<br/>Each message = one ID, globally ordered]
    TOB --> EQUIV[Equivalent to consensus]
```

**The connection**: Total order broadcast ↔ consensus ↔ linearizable compare-and-swap.
These three problems are equivalent in power. If you can solve one, you can solve the others.

---

## The Many Faces of Consensus

Consensus appears as the foundation of multiple distributed systems abstractions.
Understanding their equivalence is the key theoretical insight of this chapter.

### Formal Consensus Properties

Any correct consensus algorithm must satisfy:

| Property | Definition |
|----------|-----------|
| **Uniform agreement** | No two nodes decide different values |
| **Integrity** | No node decides twice |
| **Validity** | The decided value was proposed by some node |
| **Termination** | Every non-crashed node eventually decides |

*Termination* is the liveness property — the algorithm must make progress. The other three are safety properties — nothing bad happens.

### Equivalent Abstractions

```mermaid
graph TD
    CONS[Consensus<br/>Single-value agreement] <-->|equivalent power| TOB[Total Order Broadcast<br/>All nodes deliver messages in same order]
    TOB <-->|equivalent power| LIN[Linearizable Compare-and-Swap<br/>Atomic read-modify-write]
    LIN <-->|equivalent power| LOCK[Distributed Lock with Fencing Token<br/>Exclusive access with ordered grants]
    
    note1[If you can implement one,<br/>you can implement all others<br/>They are all equally hard]
```

### Consensus in Practice

Real consensus is expensive — every decision requires a full round-trip to a majority of nodes. Practical systems minimize how often they invoke consensus:

```mermaid
graph LR
    ELEC[Leader election<br/>Invoke consensus once<br/>to elect a leader] --> LEAD[Leader period<br/>Leader processes requests<br/>without consensus<br/>— just log replication]
    LEAD --> FAIL[Leader fails] --> ELEC
    note1[Consensus overhead: O(1) per leader election<br/>Not O(1) per request<br/>That's why Raft/ZAB are practical]
```

---

## Coordination Services (ZooKeeper, etcd)

ZooKeeper and etcd are purpose-built consensus-based coordination services. They should
not be used as application databases — they're designed for small amounts of infrequently
changing coordination data.

```mermaid
graph TD
    ZK[ZooKeeper / etcd] --> LE[Leader Election<br/>Ephemeral node: first to create wins<br/>Others watch for deletion → re-election]
    ZK --> LOCK[Distributed Locks<br/>Ephemeral sequential nodes<br/>Lowest sequence number = lock holder]
    ZK --> SR[Service Discovery<br/>Ephemeral node per running instance<br/>Dead instance → node disappears]
    ZK --> CF[Configuration<br/>Watch for config changes<br/>Push to all subscribers]
    ZK --> ID[Unique ID generation<br/>Sequential ephemeral nodes<br/>→ monotonically increasing IDs]
    ZK --> MEM[Cluster membership<br/>Which nodes are currently alive?]
```

**Ephemeral nodes**: automatically deleted when the creating session ends (heartbeat stops).
This makes them ideal for registering "I am alive" presence.

**Watches**: clients register a callback on a path. ZooKeeper notifies the client when
that path changes. Used to build reactive systems: "when the leader node disappears, elect a new one."

**Operational characteristics**:
- ZooKeeper: ensemble of typically 3 or 5 nodes; linearizable writes, may serve stale reads
- etcd: used by Kubernetes for all cluster state; linearizable reads and writes via Raft
- Both: designed for kilobytes of data, not gigabytes. Not a substitute for a database.

---

## Consistency Versus Availability in Leader Election

During a network partition, a consensus-based leader election must choose:

```mermaid
graph LR
    PARTITION[Network partition: 2 halves of cluster]

    subgraph "Minority half (2 nodes)"
        MH[Cannot elect leader<br/>Don't have majority<br/>Return errors — CP]
    end

    subgraph "Majority half (3 nodes)"
        MJ[Elect new leader<br/>Continue serving — CP]
    end

    PARTITION --> MH
    PARTITION --> MJ

    note1[This is the correct behavior for CP systems<br/>The minority half refuses to serve<br/>to avoid split-brain]
```

**ZooKeeper/Raft behavior**: If a node cannot reach a quorum, it stops serving requests.
This is deliberate — consistency over availability. The system recovers when the partition heals.

**Why this matters for your system**: Any service that uses ZooKeeper/etcd for leader
election inherits this behavior. Plan for "ZooKeeper quorum lost → your service stops accepting
writes" as a real failure mode.

---

## Compare-and-Set as Consensus

Linearizable compare-and-set (CAS) is equivalent in power to consensus:

```python
# Atomic CAS: only sets new_value if current value == expected_value
if compare_and_set(key, expected=old_value, new=new_value):
    # success — we "won" the competition
else:
    # another writer changed it first — retry
```

```mermaid
graph LR
    CAS[Linearizable CAS] <-->|equivalent| CONS[Consensus<br/>agree on one value]
    CONS <-->|equivalent| TOB[Total Order Broadcast]
    TOB <-->|equivalent| LID[Linearizable ID Generator]
    
    note1[All require the same fundamental capability:<br/>agreement across nodes in the face of failures<br/>All are equally hard to implement correctly]
```

**Fetch-and-add**: Another atomic primitive equivalent to consensus. Used in ticket servers (monotonically increasing IDs), sequence numbers.

**Subtleties of consensus**:
1. **Liveness vs safety**: Raft guarantees safety (never decides wrong value) always. Liveness (eventually decides) only holds if a majority of nodes are alive and can communicate.
2. **Leader epoch**: Each leader has a monotonically increasing epoch (term in Raft). Followers reject messages from old leaders by comparing epoch numbers.
3. **Performance**: Consensus requires a round-trip to a quorum for every decision. Batching writes amortizes this cost — log many entries, commit in one round.

---

## Managing Configuration with Coordination Services

ZooKeeper and etcd are used as the single source of truth for dynamic cluster configuration:

```mermaid
graph LR
    subgraph "Configuration Management"
        ZNODE["/config/feature_flags<br/>/config/shard_assignment<br/>/config/leader_id"]
        
        SVC1[Service A] -->|watch| ZNODE
        SVC2[Service B] -->|watch| ZNODE
        SVC3[Service C] -->|watch| ZNODE
        
        OPS[Operator] -->|writes new config| ZNODE
        ZNODE -->|notifies via watch| SVC1
        ZNODE -->|notifies via watch| SVC2
    end
```

**Using shared logs for state machine replication**: ZooKeeper's ZAB protocol maintains a total order log of all writes. Any system that replicates this log processes the same sequence of operations → identical state on all nodes. This is the foundation of "state machine replication" — the general technique behind Raft, Paxos, and ZAB.

```mermaid
graph LR
    L[Shared Log<br/>Total order of operations]
    L -->|replay in order| R1[Replica 1 state machine]
    L -->|same order| R2[Replica 2 state machine]
    L -->|same order| R3[Replica 3 state machine]
    
    note1[All replicas start from same state<br/>Apply same operations in same order<br/>→ arrive at identical state<br/>This is linearizability]
```

**Shared log use cases**: Leader election, distributed lock management, cluster membership tracking, database redo log shipping, Kafka's internal topic partition assignment.

**etcd vs ZooKeeper**:
- etcd: gRPC API, Raft consensus, used by Kubernetes; simpler ops, newer
- ZooKeeper: Java, ZAB consensus, mature ecosystem, used by HBase/Kafka/Hadoop

---

## ZooKeeper in Practice

```mermaid
graph LR
    ZK[ZooKeeper / etcd] --> LE[Leader election<br/>Ephemeral znodes + watches]
    ZK --> CF[Configuration management<br/>Watch for config changes]
    ZK --> LK[Distributed locks<br/>Ephemeral sequential znodes]
    ZK --> SR[Service registry<br/>Ephemeral node per service instance]
    ZK --> ID[Unique ID generation<br/>Sequential znodes → monotonic IDs]
```

**Ephemeral node**: Automatically deleted when the creating session ends (node crashes).
Used for leader registration — if leader crashes, its znode disappears, triggering re-election.
