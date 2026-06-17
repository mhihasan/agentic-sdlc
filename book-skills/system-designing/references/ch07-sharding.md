# Chapter 7: Sharding (Partitioning)

## Core Thesis
Sharding splits a dataset across multiple nodes so that each node is responsible for a
subset of the data. It's the primary mechanism for scaling beyond a single machine's
limits. The central challenge: distributing data evenly while supporting the query patterns
your application needs.

---

## Replication vs Sharding — Different Problems

```mermaid
graph LR
    subgraph "Replication: same data, multiple nodes"
        L[Leader: all data] --> F1[Follower: all data]
        L --> F2[Follower: all data]
    end

    subgraph "Sharding: different data, different nodes"
        N1[Node 1: keys A–M]
        N2[Node 2: keys N–Z]
        N3[Node 3: keys 0–9]
    end
```

In practice, replication and sharding are combined: each shard is replicated.

---

## Sharding Strategies

### 1. Key-Range Sharding

```mermaid
graph LR
    K[Key Space] --> S1[Shard 1: A–F]
    K --> S2[Shard 2: G–M]
    K --> S3[Shard 3: N–S]
    K --> S4[Shard 4: T–Z]
```

**Advantages**:
- Efficient range scans: `WHERE key BETWEEN 'G' AND 'K'` hits one shard
- Easy to understand

**Disadvantages**:
- Hot spots: if keys are time-ordered, all writes go to the "current" shard
- Uneven distribution if key distribution is skewed

**Fix for time-series hot spots**: Prefix key with something other than timestamp, or use
`sensor_id + timestamp` where the shard key is `sensor_id`.

### 2. Hash Sharding

```mermaid
graph LR
    K[Key] --> H["hash(key)"]
    H --> S1["Shard 1: hash 0–25%"]
    H --> S2["Shard 2: hash 25–50%"]
    H --> S3["Shard 3: hash 50–75%"]
    H --> S4["Shard 4: hash 75–100%"]
```

**Advantages**:
- Uniform distribution of random keys
- No hot spots from sequential keys

**Disadvantages**:
- ❌ Range queries require scatter-gather (hit all shards)
- Rebalancing: adding/removing nodes requires moving data

### 3. Hash + Range (Compound Sharding)

DynamoDB's model: **partition key** (hash → determines shard) + **sort key** (range within shard).

```mermaid
graph LR
    PK["Partition Key: user_id (hash sharded)"] --> S1[Shard]
    SK["Sort Key: timestamp (range within shard)"] --> S1
    S1 --> Q["Query: user_id=X, timestamp BETWEEN t1 AND t2<br/>→ single shard, efficient range scan"]
```

---

## Consistent Hashing

```mermaid
graph TD
    subgraph "Hash Ring (0 → 2^32)"
        R1[Node A: 0–90°]
        R2[Node B: 90°–180°]
        R3[Node C: 180°–270°]
        R4[Node D: 270°–360°]
    end

    K1["Key K1 → hash 45°"] --> R1
    K2["Key K2 → hash 200°"] --> R3

    ADD[Add Node E at 135°] --> MOVED["Only keys 90°–135° move<br/>from B to E"]
```

**Benefit**: Adding/removing a node only moves `1/n` of keys (not all keys).
**Used by**: Amazon DynamoDB, Apache Cassandra, Chord protocol.

---

## Handling Hot Spots (Skewed Workloads)

Even with hash sharding, a celebrity's user_id will create a hot key (millions of reads/writes):

```mermaid
graph TD
    HOTKEY["Hot key: user_id=12345<br/>(Justin Bieber, 100M writes/s)"]
    HOTKEY --> SPLIT["Split: write to<br/>user_id_random_suffix<br/>user_id_00, user_id_01, ... user_id_99"]
    SPLIT --> SCATTER["Reads: scatter-gather across all 100 keys<br/>→ application merges"]
```

This is a manual application-level fix; databases don't do this automatically (as of DDIA 2e).

---

## Sharding and Secondary Indexes

Secondary indexes on sharded data create a fundamental problem:

### Local Secondary Indexes (Document-Partitioned)

```mermaid
graph LR
    subgraph "Shard 1: cars with ID 0-499"
        D1[car:153 red Honda]
        D2[car:277 red Toyota]
        LSI1["Local index:<br/>color:red → [153, 277]"]
    end
    subgraph "Shard 2: cars with ID 500-999"
        D3[car:512 red BMW]
        LSI2["Local index:<br/>color:red → [512]"]
    end

    Q["Query: color=red"] --> SC[Scatter-gather<br/>both shards!]
```

Write: ✅ Only touches one shard  
Read by secondary key: ❌ Must scatter to all shards  

### Global Secondary Indexes (Term-Partitioned)

```mermaid
graph LR
    subgraph "Data Shards"
        DS1[Shard A: data]
        DS2[Shard B: data]
    end

    subgraph "Index Shards"
        GI1["Index Shard 1:<br/>color:blue → [car:10, car:312...]"]
        GI2["Index Shard 2:<br/>color:red → [car:153, car:512...]"]
    end

    DS1 -->|update| GI1
    DS2 -->|update| GI1
    Q["Query: color=red"] --> GI2
    GI2 --> DS1
    GI2 --> DS2
```

Read: ✅ Single index shard lookup  
Write: ❌ Must update both data shard AND index shard (distributed write, async or 2PC)  

---

## Rebalancing Shards

When adding/removing nodes, data must move:

| Strategy | How | Trade-off |
|----------|-----|----------|
| Hash mod N | `hash(key) % N` — all keys move when N changes | ❌ Massive data movement |
| Fixed shards | Pre-create 1000 shards, assign multiple to each node | ✅ Only move shards, not keys |
| Dynamic splitting | Shard splits when too large (HBase, RethinkDB) | ✅ Adapts to data distribution |
| Consistent hashing | Move only adjacent key space | ✅ Minimal movement |

**Fixed number of shards** (Elasticsearch, Riak): Create far more shards than nodes at the
start. When adding a node, move some shards to it. Cannot change shard count after creation.

---

## Request Routing — How Does a Client Find the Right Shard?

```mermaid
graph TD
    A{Routing approach} --> R1[Client-side routing<br/>Client knows the shard map]
    A --> R2[Routing tier<br/>Dedicated router (ZooKeeper-aware)]
    A --> R3[Gossip protocol<br/>Client can contact any node,<br/>gets redirected]

    R1 --> Z[ZooKeeper / etcd<br/>Source of truth for shard assignment]
    R2 --> Z
```

**ZooKeeper** is the dominant coordination service for shard assignment metadata.
HBase, SolrCloud, Helix all use ZooKeeper for this.

---

### Cell-Based Architecture (Sharding for Multitenancy)

A cell is a complete, independent instance of the entire stack — including DB, services,
and infrastructure — serving a subset of tenants:

```mermaid
graph TD
    subgraph "Cell-Based Architecture"
        LB[Global Load Balancer / Router]
        LB -->|tenant A-G| CELL1[Cell 1<br/>App + DB + Cache<br/>Tenants: A–G]
        LB -->|tenant H-N| CELL2[Cell 2<br/>App + DB + Cache<br/>Tenants: H–N]
        LB -->|tenant O-Z| CELL3[Cell 3<br/>App + DB + Cache<br/>Tenants: O–Z]
    end
```

**Advantages over simple sharding**:
- Blast radius isolation: a bug/outage in Cell 1 doesn't affect Cell 2
- Independent deployments: roll out new version to Cell 1, validate, then proceed
- Regulatory compliance: route EU tenants to EU cells for data residency
- Per-cell backup/restore: restore a single tenant's cell without touching others
- Gradual schema migrations: migrate Cell 1 first, then Cell 2

**When to use**: SaaS platforms with many enterprise tenants, especially when tenants have
strict isolation, compliance, or SLA requirements (Shopify, Salesforce, GitHub use this).

**Complexity**: Cell management infrastructure is significant — routing, provisioning,
monitoring, and deploying N identical cells adds operational overhead.

---

## Sharding Decision Framework

```mermaid
flowchart TD
    A{Data fits on one node?} -->|Yes| SINGLE[Single node<br/>Don't shard prematurely]
    A -->|No| B{Primary access pattern?}
    B -->|Point lookups by key| HASH[Hash sharding<br/>DynamoDB, Cassandra]
    B -->|Range scans over key| RANGE[Range sharding<br/>HBase, BigTable]
    B -->|Geo queries| GEO[Geospatial sharding<br/>Geohash prefix ranges]
    B -->|Multitenancy isolation| TENANT[Shard-per-tenant<br/>Separate keyspace/table]
```
