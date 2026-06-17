# Chapter 4: Storage and Retrieval

## Core Thesis
The internals of storage engines directly determine performance characteristics. You cannot
reason about DB performance, capacity planning, or choosing between systems without
understanding the fundamental data structures underneath: B-trees and LSM-trees. Each is
optimized for different workloads, and neither is universally better.

---

## The Simplest Possible Storage Engine

```bash
# Append-only log — the foundation of almost everything
echo "$1,$2" >> database  # set(key, value)
grep "^$1," database | tail -1 | cut -d',' -f2  # get(key)
```

This illustrates the core insight: **appending to a log is the fastest possible write**.
The cost is paid on reads. Every real storage engine is a variation on how to make reads
faster without making writes too slow.

---

## Log-Structured Storage (LSM-Trees)

### MemTable + SSTable Architecture

```mermaid
graph TD
    W[Write] --> MT[MemTable<br/>In-memory sorted tree<br/>Red-black / AVL]
    MT -->|flush when full| SST1[SSTable Level 0<br/>Immutable, sorted]
    SST1 -->|compaction| SST2[SSTable Level 1<br/>Larger, fewer files]
    SST2 -->|compaction| SST3[SSTable Level 2...]

    R[Read] --> MT
    MT -->|not found| BF[Bloom Filter<br/>Probabilistic skip]
    BF -->|may exist| SST1
    SST1 --> SST2

    WAL[Write-Ahead Log<br/>Crash recovery] --> MT
```

**SSTable (Sorted String Table)**:
- Keys sorted within file
- Each file is immutable once written
- Compaction merges and purges deleted/old keys

**Bloom Filter**: Probabilistic data structure — answers "definitely not in this file" or
"probably in this file" with zero false negatives. Crucial for read performance in LSM-trees.

### Compaction Strategies

```mermaid
graph LR
    subgraph "Size-Tiered Compaction (Cassandra default)"
        S0[L0: 4 small SSTables] -->|merge| S1[L1: 1 larger SSTable]
        S1 -->|accumulate 4| S2[L2: merge again]
        note1[Write-optimized<br/>Fewer writes to disk<br/>Higher space amplification]
    end

    subgraph "Leveled Compaction (RocksDB default)"
        L0[L0: few small] --> L1[L1: fixed total size]
        L1 --> L2[L2: 10× larger than L1]
        L2 --> L3[L3: 10× larger than L2]
        note2[Read-optimized<br/>Lower space amplification<br/>More write I/O]
    end
```

---

## B-Tree Storage

```mermaid
graph TD
    ROOT[Root Page<br/>256, 512] --> N1[Node<br/>100, 200]
    ROOT --> N2[Node<br/>300, 400]
    ROOT --> N3[Node<br/>600, 700]
    N1 --> L1[Leaf: 10, 50, 100]
    N1 --> L2[Leaf: 150, 200]
    N2 --> L3[Leaf: 256, 300]
    N3 --> L4[Leaf: 601, 700]
```

**B-tree properties**:
- Fixed-size pages (typically 4KB–16KB)
- `branching factor` (number of child pointers per page) = typically 500
- A 4-level tree with branching factor 500 can store 500⁴ = 62.5 billion keys
- **In-place updates**: overwrites existing pages on disk

**Write-Ahead Log (WAL)** for crash safety:
```mermaid
sequenceDiagram
    participant App
    participant WAL
    participant BTree
    App->>WAL: Append write operation
    WAL-->>App: Ack
    App->>BTree: Modify page in memory
    BTree->>Disk: Flush page
    note over WAL: If crash, replay WAL to restore B-tree
```

---

## LSM-Tree vs B-Tree — The Critical Decision

| Dimension | LSM-Tree | B-Tree |
|-----------|----------|--------|
| **Write throughput** | ✅ Higher (sequential appends) | ❌ Lower (random in-place writes) |
| **Read latency** | ❌ Higher (check multiple levels) | ✅ Lower (predictable page traversal) |
| **Write amplification** | Medium (compaction rewrites data) | Lower (only write data once… mostly) |
| **Space amplification** | Medium (old versions until compaction) | Low (in-place, predictable) |
| **Compression** | ✅ Better (contiguous data) | ❌ Worse (fragmentation) |
| **Compaction impact** | ⚠️ Can throttle writes during heavy compaction | N/A |
| **Range queries** | ✅ Efficient (sorted SSTables) | ✅ Efficient (sorted pages) |
| **Best for** | Write-heavy workloads, time-series | Read-heavy, latency-sensitive |
| **Examples** | RocksDB, Cassandra, DynamoDB, LevelDB | PostgreSQL, MySQL InnoDB, SQLite |

**Write amplification**: One logical write causes multiple physical writes (compaction,
WAL, actual data). For SSDs with limited write endurance, this matters.

---

## Indexes

### Primary vs Secondary Index

```mermaid
graph LR
    subgraph "Clustered / Primary"
        PK[Primary Key Index] --> DATA[Data rows<br/>stored inside index]
    end
    subgraph "Non-Clustered / Secondary"
        SK[Secondary Key Index] --> REF[Row references<br/>→ heap file / primary key]
        REF --> DATA2[Data rows<br/>stored separately]
    end
```

- **Clustered index** (InnoDB, DynamoDB): Data stored sorted by PK. Fast PK lookups.
  Secondary indexes hold PK value as row reference.
- **Heap file**: Data stored separately from index. More flexible, avoids duplication.

### Multi-Column / Composite Indexes

```sql
-- Index on (latitude, longitude) for geo queries
-- Efficient for: WHERE lat BETWEEN x1 AND x2 AND lon BETWEEN y1 AND y2
CREATE INDEX idx_location ON restaurants(latitude, longitude);
```

A 2D index maps to a 1D space via space-filling curves (R-trees, geohash). PostGIS uses this.

### Full-Text Search Indexes (Inverted Index)

```mermaid
graph LR
    D1["Doc 1: 'quick brown fox'"]
    D2["Doc 2: 'fox jumps over dog'"]

    W1[quick → Doc1]
    W2[brown → Doc1]
    W3[fox → Doc1, Doc2]
    W4[jumps → Doc2]
    W5[dog → Doc2]
```

---

## In-Memory Databases

**Why in-memory can be faster** is often misunderstood:
- NOT because avoiding disk reads (OS page cache does that anyway)
- IS because avoiding the overhead of encoding data in a disk-compatible format
- AND because data structures that don't need to be disk-safe (e.g., priority queues, sets)

**Durability options**:
1. Snapshot to disk periodically (Redis default)
2. Append-only log of operations (Redis AOF)
3. Replication to other nodes
4. NVM (non-volatile memory) — emerging

**Examples**: Redis (cache + limited durability), VoltDB (full ACID in-memory), RAMCloud.

---

## Column-Oriented Storage (for Analytics)

### Row vs Column Layout

```mermaid
graph TD
    subgraph "Row-Oriented"
        R1[row1: id=1, name='Alice', age=30, city='NYC']
        R2[row2: id=2, name='Bob', age=25, city='LA']
        R3["Query: SELECT city FROM users WHERE age > 28<br/>→ must read all columns per row"]
    end

    subgraph "Column-Oriented"
        C1["id col: [1, 2, 3, 4...]"]
        C2["name col: ['Alice','Bob'...]"]
        C3["age col: [30, 25, 35, 28...]"]
        C4["city col: ['NYC','LA','SF'...]"]
        R4["Query: read only age col + city col<br/>→ 10-100× less I/O for analytics"]
    end
```

### Column Compression

Columns store the same type of data repeatedly → excellent compression:

| Technique | How | When |
|-----------|-----|------|
| Bitmap encoding | One bit per row per value | Low-cardinality columns (status, country) |
| Run-length encoding | "value × count" | Sorted, repetitive data |
| Delta encoding | Store diffs, not values | Time-series, monotonic IDs |
| Dictionary encoding | Map values to integers | String columns |

**Vectorized processing**: SIMD CPU instructions can process compressed column data in bulk —
query engines like DuckDB, ClickHouse exploit this heavily.

### Sort Order in Column Storage

```mermaid
graph LR
    Sort[Sort by date_id first,<br/>then product_id] --> RLE[Run-length encoding<br/>works very well on sorted date_id]
    Sort --> CP[Query on date range<br/>skips most data]
    Sort --> Replica[Different replicas<br/>sorted differently for<br/>different query patterns]
```

**Materialized views / Cubes**: Pre-aggregate common queries (SUM by product by date).
Fast at query time, stale on writes. Trade-off: write overhead vs query speed.

---

## Query Execution: Compilation and Vectorization

Two approaches to fast analytical query execution on columnar data:

```mermaid
graph LR
    subgraph "Query Compilation (JIT)"
        SQL[SQL Query] -->|compile to native code| LLVM[LLVM / machine code]
        LLVM -->|runs directly on compressed data| RESULT1[Result]
        note1[No interpreter overhead<br/>Tight inner loops<br/>Used by: HyperDB, Umbra, DuckDB]
    end

    subgraph "Vectorized Processing (SIMD)"
        SQL2[SQL Query] -->|interpreted, batch mode| OPS[Predefined operators]
        OPS -->|process 1024 values at a time| BITMAP[Bitmap operations]
        BITMAP --> RESULT2[Result]
        note2[SIMD CPU instructions<br/>Compressed data processed in bulk<br/>Used by: ClickHouse, Vectorwise, DuckDB]
    end
```

**Both approaches leverage**:
- Sequential memory access (CPU cache-friendly)
- SIMD (Single Instruction, Multiple Data) parallelism
- Operating on compressed column data directly without decompression overhead

---

## Materialized Views and Data Cubes

**Materialized view**: Actual copy of query results stored on disk (not a virtual/logical view).
Updated when source data changes.

```mermaid
graph LR
    RAW[Fact table: 10B rows] -->|pre-aggregate| CUBE[Data Cube / OLAP Cube]

    subgraph "Data Cube — 2D example"
        D1["Axis 1: date_key"]
        D2["Axis 2: product_sk"]
        CELL["Each cell: SUM(sales)<br/>for that date × product"]
    end

    CUBE -->|fast| Q1["Total sales by product? → sum column"]
    CUBE -->|fast| Q2["Sales by date? → sum row"]
    CUBE -->|cannot| Q3["Sales where price > $100? → not a dimension"]
```

**Trade-off**:
- ✅ Pre-computed aggregates are very fast to query
- ❌ Data cube only supports queries on its defined dimensions
- ❌ Write overhead: materialized view must be updated on every source change
- Best practice: keep as much raw data as possible; use cubes only as performance boost for known common queries

---

## Multidimensional Indexes

B-trees and LSM-trees support single-dimension range queries efficiently. For multiple simultaneous dimensions, specialized indexes are needed:

```mermaid
graph TD
    subgraph "Single-dimension index — inadequate for geo"
        Q1["SELECT * WHERE lat BETWEEN x1 AND x2<br/>AND lon BETWEEN y1 AND y2"]
        Q1 -->|B-tree on lat alone| SCAN["Returns all lat in range regardless of lon<br/>Then filters — very expensive"]
    end

    subgraph "Multidimensional index — R-tree"
        RTREE[R-Tree / Bkd-Tree]
        RTREE -->|splits space recursively| BOX1[Bounding box 1]
        RTREE --> BOX2[Bounding box 2]
        BOX1 --> LEAF[Nearby points grouped together]
        Q2["2D query → prune entire subtrees<br/>dramatically fewer comparisons"]
    end
```

**R-tree** (PostGIS): Recursively partitions space into bounding rectangles.
**Space-filling curve** (geohash): Maps 2D to 1D by interleaving bits of lat/lon.
**Applications**: geo search, color range queries (R/G/B dimensions), time+temperature sensors.

---

## Full-Text Search (Inverted Index)

```mermaid
graph LR
    subgraph "Inverted Index"
        D1[Doc 1: 'quick brown fox']
        D2[Doc 2: 'fox jumps high']

        T1[quick → [Doc1]]
        T2[brown → [Doc1]]
        T3[fox → [Doc1, Doc2]]
        T4[jumps → [Doc2]]
    end

    Q["Search: 'brown fox'"] --> T2
    Q --> T3
    T2 & T3 -->|AND → bitwise AND of bitmaps| R[Doc1]
```

**Implementation (Lucene/Elasticsearch)**:
- Postings list stored in SSTable-like sorted files
- Merged in background (same log-structured approach as LSM-trees)
- Supports fuzzy matching via Levenshtein automaton (edit distance = 1 typo tolerance)
- Trigram indexing for substring/regex search

**PostgreSQL GIN index**: Native inverted index supporting full-text search and JSON document indexing.

---

## Vector Embeddings and Semantic Search (2nd Edition Addition)

Traditional search: keyword matching (exact or fuzzy).
Semantic search: find documents with similar *meaning*, not identical words.

```mermaid
graph LR
    DOC[Document: 'cancel subscription'] -->|embedding model| VEC["Vector: [0.38, 0.83, 0.41, ...]<br/>~1000+ dimensions"]
    QUERY[User query: 'close my account'] -->|same model| QVEC["Query vector: [0.39, 0.81, 0.44, ...]"]
    QVEC -->|cosine similarity| ANN[Approximate Nearest Neighbor search]
    ANN --> MATCH[Match: 'cancel subscription']
    note1[Similar meaning → similar vectors in embedding space<br/>Different words, same concept]
```

**Vector Index Types**:

| Type | How | Speed | Accuracy |
|------|-----|-------|----------|
| Flat | Compare query against every vector | Slowest | Exact |
| IVF (Inverted File) | Cluster vectors into centroids; search nearest clusters | Fast | Approximate |
| HNSW (Hierarchical Navigable Small World) | Graph of proximity layers; greedy search | Very fast | Approximate |

**Key term clarification**:
- "Vectorized processing" (column DB) = batch CPU operations on compressed data
- "Vector embedding" (semantic search) = floating-point array representing meaning in high-dimensional space
These are unrelated despite the naming collision.

**Products**: pgvector (PostgreSQL), Pinecone, Weaviate, Chroma, Qdrant. Facebook's Faiss library implements IVF and HNSW.

---

## Storage Engine Selection Guide

```mermaid
flowchart TD
    A{Primary workload?} -->|OLTP, write-heavy| B{Write pattern?}
    A -->|OLAP, analytics| COL[Column-Oriented<br/>BigQuery, ClickHouse, Parquet]
    A -->|Mixed HTAP| HY[Hybrid: TiDB, SingleStore]

    B -->|Time-series, append-only| LSM[LSM-Tree<br/>Cassandra, RocksDB, DynamoDB]
    B -->|Mixed read/write, latency-sensitive| BT[B-Tree<br/>PostgreSQL, MySQL, SQLite]
    B -->|Mostly reads, latency critical| MEM[In-Memory<br/>Redis, Memcached]
```
