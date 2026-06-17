# Chapter 9: The Trouble with Distributed Systems

## Core Thesis
Distributed systems are fundamentally different from single-node software. The hardware
and network are unreliable in ways you cannot fully control. You must assume things will
fail — in partial, unpredictable ways — and design systems that behave correctly anyway.
This chapter is a catalogue of what can go wrong; Chapter 10 addresses how to cope.

---

## Partial Failures — The Defining Problem

```mermaid
graph LR
    subgraph "Single Node"
        CPU[CPU] --> MEM[Memory]
        MEM --> DISK[Disk]
        note1[If hardware fails: total crash<br/>Deterministic — either works or doesn't]
    end

    subgraph "Distributed System"
        N1[Node A] -->|Network| N2[Node B]
        N2 -->|Network| N3[Node C]
        note2[Node B may be slow but not dead<br/>Packet may arrive after 30 seconds<br/>Node may receive but not respond<br/>PARTIAL FAILURE — non-deterministic]
    end
```

**The fundamental challenge**: You cannot distinguish between "node is dead" and "network
is very slow" from the outside. This ambiguity is the root cause of most distributed
systems complexity.

---

## Unreliable Networks

Everything that can happen to a network message:

```mermaid
graph TD
    SEND[Send request] --> Q1{Packet lost?}
    Q1 -->|Yes| LOST1[Request never arrives]
    Q1 -->|No| Q2{Remote node processing?}
    Q2 -->|Node crashed| LOST2[Request processed 0%]
    Q2 -->|Node slow| SLOW[Request queued, processed eventually]
    Q2 -->|Normal| PROC[Request processed]
    PROC --> Q3{Response lost?}
    Q3 -->|Yes| LOST3[Response never arrives]
    Q3 -->|No| Q4{Response delayed?}
    Q4 -->|Yes| LATE[Response arrives after timeout — looks like failure]
    Q4 -->|No| OK[Response received]
```

**Key insight**: The sender has no way to know which of these occurred. A timeout can only
tell you "something went wrong" — not what.

### Timeout Selection — No Right Answer

```mermaid
graph LR
    SHORT[Short timeout] --> FP[False positive failure detection<br/>Unnecessary failovers]
    SHORT --> OVERLOAD[Retry storms under load<br/>Amplifies the problem]
    LONG[Long timeout] --> SLOW[Slow failure detection<br/>Long recovery time]
    LONG --> UX[Bad user experience<br/>Waits for failed node]
```

**Best practice**: Start with p99 observed latency as timeout baseline. Use exponential
backoff + jitter. Use circuit breakers to stop sending to known-bad targets.

---

## Network Congestion and Queuing

```mermaid
graph TD
    N[Many senders → single link] --> Q[Switch queue]
    Q -->|queue full| DROP[Packet dropped → TCP retransmit]
    Q -->|queue not full| DELAY[Variable delay]

    VM[VM scheduler pause] --> VMD[100ms–1s delay before OS gets CPU]
    GC[GC pause] --> GCD[Stop-the-world: process frozen]
    OS[OS scheduling] --> OSD[Thread preempted mid-operation]
```

**The implication**: Even on a fast, healthy network, latency is variable and unbounded.
You cannot assume a response will arrive within any fixed time. All timeouts are guesses.

---

## Unreliable Clocks

### Two Types of Clocks

```mermaid
graph LR
    subgraph "Time-of-Day Clock"
        TOD[Returns absolute time<br/>e.g. 2024-01-15 14:23:01 UTC]
        TOD --> NTP[Synchronized via NTP<br/>Can jump backward!<br/>±100ms accuracy typical]
        TOD --> JUMP[Can jump forward/backward<br/>if NTP correction is applied]
    end

    subgraph "Monotonic Clock"
        MON[Returns elapsed time<br/>e.g. 2,345,678 ns since boot]
        MON --> NOBACK[Never goes backward]
        MON --> REL[Relative only — useless across machines]
    end
```

**Use monotonic clocks for**: measuring duration of an operation, timeouts.  
**Use time-of-day clocks for**: event timestamps, scheduling (with caution).

### Why Clocks Are Untrustworthy

| Issue | Detail |
|-------|--------|
| NTP accuracy | Typically ±1–100ms. Google TrueTime uses GPS/atomic: ±1ms |
| NTP leap second | Clocks can go backward or stall |
| VM clock | Hypervisor can freeze a VM while clock still ticks on host; then VM "catches up" |
| Quartz drift | Cheap clocks drift 10–200 ppm (6 seconds/day fast or slow) |

### The Danger of Timestamps for Ordering

```mermaid
sequenceDiagram
    participant N1 as Node 1 (clock: 10:00:00.000)
    participant N2 as Node 2 (clock: 10:00:00.005 — 5ms ahead)

    N1->>DB: Write X=1 at t=10:00:00.000
    N2->>DB: Write X=2 at t=10:00:00.005
    note over DB: Correct order: X=1 then X=2

    N1->>DB: Write Y=1 at t=10:00:00.010
    N2->>DB: Write Y=2 at t=10:00:00.003  ← N2 clock reset
    note over DB: WRONG: Y=2 has earlier timestamp than Y=1<br/>Last-write-wins discards Y=1 incorrectly
```

**Google Spanner's TrueTime**: Returns time as an interval `[earliest, latest]` with
bounded uncertainty. When ordering events, wait until the uncertainty window has passed.
Feasible with GPS + atomic clocks; not practical for most deployments.

---

## Process Pauses

A process can be paused for arbitrarily long times:

```mermaid
graph LR
    P[Process running<br/>believes it's the leader] --> GC[GC stop-the-world<br/>20 seconds]
    GC --> RESUME[Process resumes<br/>still believes it's leader]
    RESUME --> ACT[Acts as leader<br/>makes writes]
    RESUME2[But: new leader elected<br/>during the pause] --> CONF[CONFLICT!]
```

**Causes of process pauses**:
- Garbage collection (JVM G1 pauses can be 100ms–10s)
- Virtual machine live migration (VM paused while moved to another host)
- OS `SIGSTOP` / debugger breakpoint
- Swap/paging — process waiting for disk
- CPU scheduling — hypervisor gives CPU to another VM

**Why this matters**: Any algorithm that assumes "if I didn't hear from node X in time T, it
must be dead" is vulnerable. The node could just be paused.

---

## Fencing Tokens — Preventing Stale Leader Writes

```mermaid
sequenceDiagram
    participant L1 as "Old Leader (paused)"
    participant L2 as "New Leader"
    participant LS as "Lock Service (ZooKeeper)"
    participant Storage

    L1->>LS: Acquire lock → token=33
    LS-->>L1: OK, token=33
    note over L1: GC pause — 30 seconds
    L2->>LS: Acquire lock (L1 expired) → token=34
    LS-->>L2: OK, token=34
    L2->>Storage: Write with token=34 ✅
    note over L1: Resumes, thinks it still has the lock
    L1->>Storage: Write with token=33
    Storage-->>L1: REJECTED — token=33 < current=34 ✅
```

**Fencing token**: A monotonically increasing number from the lock service. Storage layer
rejects writes from tokens lower than the highest seen.

---

## Knowledge, Truth, and Lies

In distributed systems, a node cannot know the truth about the state of the system —
it can only make inferences from the messages it has received. This has profound implications.

**"A node cannot trust its own judgment"**:
- A node believes it's the leader — but the network partition means others have elected a new one
- A node believes its lock is valid — but the lock service timed it out while the node was GC-paused
- A node believes a write succeeded — but the response was lost on the network

```mermaid
graph TD
    NODE[Node X believes it's the leader] --> REALITY{What's actually true?}
    REALITY -->|partition| REAL1[Another leader elected — X is stale]
    REALITY -->|GC pause| REAL2[Lease expired — X no longer holds the lock]
    REALITY -->|network drop| REAL3[Write not received — despite X thinking it succeeded]
    
    LESSON[Lesson: Design systems so a node acting on wrong beliefs causes no harm<br/>Fencing tokens, idempotency, quorum checks]
```

---

## The Majority Rules

For a system to be safe, any decision requires agreement from a majority (quorum) of nodes:

```mermaid
graph LR
    subgraph "5-node cluster: majority = 3"
        N1[Node 1: vote YES]
        N2[Node 2: vote YES]
        N3[Node 3: vote YES — QUORUM REACHED]
        N4[Node 4: DOWN]
        N5[Node 5: DOWN]
        note1[2 nodes can fail, system still makes decisions<br/>A split-brain can't occur: two groups of 2 can't both reach majority]
    end
```

**Why majority (not just any quorum)?** Two disjoint majorities cannot exist in the
same cluster. If Group A has majority, Group B cannot also have majority — no split-brain.

**This is the foundation of**: Raft leader election, Paxos, ZooKeeper, and all
consensus protocols. The quorum condition `w + r > n` in leaderless replication is
the same principle applied to reads and writes.

---

## Distributed Locks and Leases

A distributed lock grants exclusive access to a resource across nodes. Key challenge:
the lock holder might crash or be paused — who decides when to release it?

```mermaid
sequenceDiagram
    participant Client1
    participant Client2
    participant LockSvc as Lock Service (ZooKeeper)
    participant Storage

    Client1->>LockSvc: Acquire lock (TTL: 30s) → token=1
    LockSvc-->>Client1: OK
    note over Client1: GC pause for 40 seconds
    LockSvc->>LockSvc: TTL expired — lock released
    Client2->>LockSvc: Acquire lock → token=2
    LockSvc-->>Client2: OK
    Client2->>Storage: Write with token=2 ✅
    note over Client1: GC resumes — believes lock is held
    Client1->>Storage: Write with token=1 ❌ REJECTED
    note over Storage: Storage rejects token=1 < current token=2<br/>This is the fencing token pattern
```

**Lease** = a time-limited lock. The holder can use the resource only until the lease expires.
**Fencing token** = monotonically increasing number from the lock service. Storage layer
must enforce that only the highest-seen token is accepted.

**Safe lock usage checklist**:
1. ✅ Lock service uses consensus (ZooKeeper, etcd) — not just a single node
2. ✅ Fencing token included in every write to storage
3. ✅ Storage layer checks and enforces fencing token
4. ✅ Client handles "lock lost" by aborting its current operation

---

## The Byzantine Generals Problem

A **Byzantine fault** is when a node behaves arbitrarily — sending incorrect or malicious
data, rather than simply being slow or crashed.

```mermaid
graph LR
    CRASH[Crash-stop faults<br/>Node dies cleanly] --> MOST[Handled by most<br/>distributed systems]
    BYZ[Byzantine faults<br/>Node lies, corrupts data] --> SPECIAL[Requires Byzantine fault-tolerant<br/>consensus — much more expensive]

    BYZ --> EX1[Blockchain consensus]
    BYZ --> EX2[Aerospace flight computers]
    BYZ --> EX3[Multi-party untrusted systems]
```

**For most distributed systems**: Assume crash-stop (or crash-recovery) faults only. Byzantine
fault tolerance adds enormous complexity and is rarely needed in controlled datacenter environments.

---

## System Models

Distributed algorithms are designed and proved against formal models:

| Model | Network | Clocks | Processes |
|-------|---------|--------|-----------|
| Synchronous | Bounded delay | Bounded drift | Bounded pause |
| Partially synchronous | Usually bounded | Usually bounded | Usually bounded |
| Asynchronous | Unbounded | No clocks | Unbounded pauses |

**Real systems are partially synchronous**: Usually behave like synchronous systems, with
occasional periods of bad behavior (congestion, GC, load spikes). Algorithms must be
correct in asynchronous model but can be tuned for partially synchronous performance.

---

## Formal Methods and Randomized Testing

Given that distributed systems have almost infinite edge cases, how do you gain confidence they're correct?

### Formal Verification
Specify the system's expected behavior mathematically and prove it holds:
- **TLA+** (Leslie Lamport): Used by Amazon, Microsoft to verify distributed algorithms. AWS found 10 bugs in internal systems using TLA+.
- **Alloy**: Model checker for relational specifications
- **Isabelle/Coq**: Full proof assistants (used to verify Raft formally)

**Practical use**: Formal methods are most valuable for core consensus/replication logic — the small, critical algorithms that everything else depends on. Not practical for entire application code.

### Fault Injection

Deliberately introduce failures in test/staging environments to verify fault-tolerance:

```mermaid
graph TD
    FI[Fault Injection Techniques]
    FI --> NC[Network chaos<br/>Drop packets, add latency, partition nodes<br/>tc netem, Chaos Monkey, Gremlin]
    FI --> CC[Clock chaos<br/>NTP jitter injection<br/>Test clock skew assumptions]
    FI --> PC[Process chaos<br/>Kill processes, simulate OOM<br/>Chaos Monkey, LitmusChaos]
    FI --> DC[Disk chaos<br/>Inject I/O errors, latency<br/>Block device fault injection]
    FI --> BC[Byzantine chaos<br/>Corrupt messages, send wrong data<br/>Jepsen test harness]
```

**Jepsen** (Kyle Kingsbury): The gold standard for distributed database testing. Runs concurrent operations while injecting network partitions, then checks whether safety invariants were violated. Has found real bugs in Cassandra, MongoDB, Elasticsearch, Redis, etc.

### The Power of Determinism

Non-determinism in distributed systems makes bugs nearly impossible to reproduce. Strategies to maximize determinism:

```mermaid
graph LR
    NDET[Non-determinism sources] --> C1[Wall clock time → use logical clocks]
    NDET --> C2[Random numbers → seed with test input]
    NDET --> C3[Network ordering → deterministic simulation]
    NDET --> C4[Concurrent threads → serialized execution in tests]
    
    DET[Deterministic testing] --> DS[Deterministic simulation<br/>FoundationDB's sim framework<br/>Tigerbeetle's simulator<br/>Run 1000 years of simulated time in minutes]
```

**Deterministic simulation** (FoundationDB approach): Run the entire distributed system in a single-threaded simulator with a fake network, fake clocks, and controlled fault injection. Deterministically reproducible bugs. FoundationDB found and fixed thousands of bugs this way before shipping.

---

## Key Takeaways

```mermaid
graph TD
    T1[Assume network delays are unbounded<br/>— use timeouts, but know they're guesses]
    T2[Assume clocks are unreliable<br/>— don't use timestamps for distributed ordering]
    T3[Assume processes can pause<br/>— use fencing tokens, not just lock expiry]
    T4[Assume partial failures<br/>— design for "request may have succeeded but response lost"]
    T5[You cannot distinguish slow from dead<br/>— design for both outcomes]
```

The only correct response to these truths is to design algorithms that are provably correct
despite them — which is what Chapter 10 addresses.
