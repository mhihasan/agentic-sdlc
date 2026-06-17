# Chapter 11: Batch Processing

## Core Thesis
Batch processing transforms large datasets by running computation over a bounded input and
producing output. It is the most reliable, scalable, and debuggable form of data processing.
Understanding its internals — especially how distributed joins and shuffles work — is essential
for building analytics pipelines and data platforms.

---

## Three Paradigms of Data Processing

```mermaid
graph TD
    DP[Data Processing Paradigms]
    DP --> OL[Online (OLTP)<br/>Request → immediate response<br/>Low latency, high availability]
    DP --> BA[Batch<br/>Large bounded input → output<br/>High throughput, no latency SLA]
    DP --> ST[Stream<br/>Continuous unbounded input<br/>Low latency, continuous output]

    BA --> USE1[ETL pipelines]
    BA --> USE2[ML training]
    BA --> USE3[Search index building]
    BA --> USE4[Data warehouse loads]
```

---

## The Unix Philosophy Applied to Data

Unix tools model the right abstractions for batch processing:

```bash
# Count most popular log URLs — Unix pipeline
cat access.log |
  awk '{print $7}' |     # extract URL
  sort |                 # sort for grouping
  uniq -c |              # count duplicates
  sort -rn |             # sort by count descending
  head -10               # top 10
```

**Unix principles carried to distributed batch**:
1. Each program does one thing well
2. Programs communicate via uniform interfaces (stdin/stdout, files)
3. Programs are composable — chain them together

```mermaid
graph LR
    INPUT[Input file] --> MAP[Map phase<br/>Filter, transform] --> SORT[Sort / Shuffle] --> REDUCE[Reduce phase<br/>Aggregate, join] --> OUTPUT[Output file]
```

This is exactly MapReduce.

---

## Distributed Filesystems (HDFS)

```mermaid
graph TD
    subgraph "HDFS Architecture"
        NN[NameNode<br/>Metadata: which blocks on which DataNodes]
        DN1[DataNode 1<br/>Blocks: 1, 4, 7]
        DN2[DataNode 2<br/>Blocks: 2, 5, 8]
        DN3[DataNode 3<br/>Blocks: 3, 6, 9]
        NN -->|block locations| DN1
        NN -->|block locations| DN2
        NN -->|block locations| DN3
    end

    subgraph "Replication"
        B1[Block 1 → DN1, DN2, DN3<br/>3-way replicated]
    end
```

**Move computation to data** (not data to computation):
- HDFS knows which node holds each block
- MapReduce scheduler assigns map tasks to nodes that hold the input data
- Reduces network I/O dramatically for large datasets

**Object Storage vs HDFS**:
- HDFS: compute and storage collocated → low latency reads, complex cluster management
- S3/GCS/Azure Blob: storage separate from compute → flexible, scalable, cheap, higher latency
- Modern trend: move to object storage + columnar formats (Parquet, ORC) + query engines (Spark, Trino)

---

## MapReduce

```mermaid
graph LR
    subgraph "Map Phase (parallel)"
        I1[Input split 1] --> M1[Mapper 1]
        I2[Input split 2] --> M2[Mapper 2]
        I3[Input split 3] --> M3[Mapper 3]
    end

    subgraph "Shuffle Phase (network)"
        M1 -->|key=A| RA[Reducer A]
        M2 -->|key=A| RA
        M3 -->|key=B| RB[Reducer B]
        M1 -->|key=B| RB
    end

    subgraph "Reduce Phase (parallel)"
        RA --> O1[Output 1]
        RB --> O2[Output 2]
    end
```

**Key properties**:
- Mapper: called once per input record, emits (key, value) pairs
- Shuffle: framework sorts and groups all values by key, sends to reducers
- Reducer: processes all values for a given key, emits final output
- No shared state between mappers or reducers — pure functional model
- On failure: just re-run the failed task (output is deterministic)

### MapReduce Word Count (Python)

```python
# Mapper
import sys
for line in sys.stdin:
    for word in line.strip().split():
        print(f"{word}\t1")

# Reducer
import sys
from itertools import groupby

for key, group in groupby(sys.stdin, key=lambda l: l.split('\t')[0]):
    count = sum(int(v.split('\t')[1]) for v in group)
    print(f"{key}\t{count}")
```

---

## Joins in Batch Processing

### Sort-Merge Join (Reduce-Side Join)

```mermaid
graph LR
    subgraph "Input datasets"
        ORDERS[Orders: user_id, product, amount]
        USERS[Users: user_id, name, country]
    end

    subgraph "Map phase"
        ORDERS -->|emit (user_id, order_data)| SORT
        USERS -->|emit (user_id, user_data)| SORT
    end

    subgraph "Reduce phase"
        SORT[Sort + group by user_id] --> RED[Reducer receives all data for user_id<br/>Joins user record with all their orders]
        RED --> OUT[Enriched order records]
    end
```

**Properties**: Works for any join size. Requires sorting/shuffling entire datasets. O(N log N).

### Broadcast Hash Join (Map-Side Join)

```mermaid
graph LR
    SMALL[Small dataset: users<br/>< 1GB → fits in memory] -->|load into hash map| MAPPER
    LARGE[Large dataset: orders<br/>Terabytes] -->|stream through| MAPPER
    MAPPER[Each mapper:<br/>for each order, lookup user in hash map] --> OUT[Joined output<br/>No shuffle needed]
```

**When to use**: One dataset is small enough to fit in memory of each mapper. No network
shuffle needed — extremely fast. Used by Spark broadcast join (`broadcast` hint).

### Partitioned Hash Join

```mermaid
graph LR
    ORDERS2[Orders partitioned by hash(user_id)] --> M1
    USERS2[Users partitioned by hash(user_id)] --> M1
    note1[Same user_id always in same partition<br/>→ mapper only needs its partition of users in memory]
    M1[Mapper: hash join within partition] --> OUT2[Joined output]
```

---

## Dataflow Engines (Spark, Flink, Tez)

MapReduce's key limitation: every step writes intermediate results to HDFS (fault tolerance
via materialization). For multi-step pipelines, this is extremely slow.

```mermaid
graph LR
    subgraph "MapReduce: Materialize every step"
        A[Step 1] -->|write to HDFS| B[Step 2]
        B -->|write to HDFS| C[Step 3]
        C -->|write to HDFS| D[Step 4]
    end

    subgraph "Dataflow Engine: Pipeline in memory"
        E[Step 1] -->|in-memory pipeline| F[Step 2]
        F -->|in-memory pipeline| G[Step 3]
        G -->|in-memory pipeline| H[Step 4]
        H -->|write once at end| I[Output]
    end
```

**Spark vs MapReduce**:
- Spark keeps intermediate results in memory (RDD/DataFrame)
- 10–100× faster for iterative algorithms (ML training: run 100 iterations → huge win)
- Fault tolerance via lineage: re-compute lost partitions from source rather than checkpointing

---

## DataFrames: The Dominant API

Modern batch processing is done almost exclusively via DataFrames (Spark, Pandas, Dask,
Polars) rather than raw MapReduce APIs. A DataFrame is a distributed, lazily-evaluated
collection of records with a schema.

```python
# Spark DataFrame example — this is the modern way
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum

spark = SparkSession.builder.getOrCreate()

# Read from S3 in Parquet format
df = spark.read.parquet("s3://bucket/events/")

# Transformations are lazy — build execution plan
result = (df
    .filter(col("event_type") == "purchase")
    .groupBy("user_id", "product_category")
    .agg(sum("amount").alias("total_spend"))
    .orderBy(col("total_spend").desc())
)

# Action triggers actual computation
result.write.parquet("s3://bucket/output/user_spend/")
```

**Lazy evaluation**: Transformations build a DAG of operations. The query optimizer
can reorder, push predicates down, and choose join strategies before any data moves.
This is equivalent to SQL's query optimizer, but for code.

**Spark vs Pandas**:
- Pandas: in-memory, single-node, `O(data_size)` RAM required
- Spark: distributed, lazy, handles datasets larger than single-machine RAM

---

## Batch Use Cases (2nd Edition Expansion)

### Extract-Transform-Load (ETL)

```mermaid
graph LR
    SRC1[OLTP DB: PostgreSQL] -->|CDC / bulk extract| E[Extract]
    SRC2[SaaS APIs: Salesforce, Stripe] -->|scheduled pull| E
    SRC3[Event logs: Kafka, S3] -->|batch read| E
    E -->|clean, join, type-cast, deduplicate| T[Transform<br/>Spark / dbt]
    T -->|load| DWH[Data Warehouse<br/>BigQuery / Snowflake / Redshift]
    DWH -->|query| BI[BI Tools: Tableau, Looker, Metabase]
```

### Analytics and Pre-Aggregation

```mermaid
graph LR
    RAW[Raw event data: 10TB/day] -->|batch aggregate| PRE[Pre-aggregated tables<br/>daily/hourly rollups]
    PRE -->|fast queries| DASH[Dashboards<br/>query in ms, not minutes]
    
    note1[Ad-hoc queries on raw data: expensive<br/>Pre-aggregated queries: cheap<br/>Trade-off: freshness vs cost]
```

**dbt (data build tool)**: SQL-based transformation layer that runs inside the data warehouse.
Defines data models as SELECT statements; manages dependencies, testing, and documentation.

### Machine Learning Batch Pipelines

```mermaid
graph TD
    subgraph "ML Batch Pipeline"
        RAW2[Raw data: S3] -->|feature engineering| FE[Feature extraction<br/>Spark job]
        FE -->|train/val/test split| FS[Feature Store<br/>Feast / Tecton / Hive]
        FS -->|training batch| TRAIN[Model Training<br/>Spark MLlib / PyTorch on GPU cluster]
        TRAIN --> MODEL[Trained model artifact<br/>MLflow / S3]
        
        subgraph "Batch Inference"
            NEW_DATA[New records batch] -->|load features| FS2[Feature Store]
            FS2 --> SCORE[Score with model]
            SCORE --> PRED[Predictions table<br/>→ DWH or serving DB]
        end
    end
```

**Feature engineering**: Transforming raw data into ML model inputs. Critical: the same
feature logic must run at training time AND at inference time — or you get training-serving skew.

**Feature Store** (Feast, Tecton): Stores pre-computed features with point-in-time correctness.
Prevents data leakage (accidentally using future data to train a model).

**Batch inference vs online inference**:
- Batch: score millions of records overnight, store results → serve from DB. Low latency, stale.
- Online: score in real-time at request time → fresh, but adds latency to each request.

### Serving Derived Data

Batch jobs don't just produce analytical outputs — they feed operational systems:

```mermaid
graph LR
    BATCH[Nightly batch job] -->|produce| SI[Search index rebuild<br/>→ Elasticsearch]
    BATCH -->|produce| REC[Recommendation model output<br/>→ DynamoDB]
    BATCH -->|produce| REPORT[Business reports<br/>→ Data Warehouse]
    BATCH -->|produce| ML2[ML model predictions<br/>→ Serving DB]
    
    note1[The output of batch processing is often the input<br/>to real-time serving systems]
```

---

## Batch Processing and Cloud Data Warehouses Converge

```mermaid
graph TD
    subgraph "Traditional separation"
        SPARK[Spark / Hadoop<br/>Unstructured batch] 
        DWH[Data Warehouse<br/>Structured SQL]
    end

    subgraph "Modern convergence"
        LAKE[Data Lakehouse<br/>Delta Lake / Iceberg / Hudi]
        LAKE --> SQL[SQL via Spark/Trino/BigQuery]
        LAKE --> PY[Python/Scala batch jobs]
        LAKE --> ML[ML training]
        LAKE --> STR[Streaming ingest]
    end
```

**Parquet** as the universal format: columnar, compressed, splittable, supported by
Spark, BigQuery, Athena, DuckDB, Pandas. The de facto interchange format for analytical data.

---

## Workflow Orchestration

```mermaid
graph LR
    WF[Workflow: A → B → C,D → E] --> ORCH[Orchestrator<br/>Airflow / Prefect / Dagster]
    ORCH --> SCHED[Schedules tasks<br/>based on dependencies]
    ORCH --> RETRY[Retries on failure]
    ORCH --> MON[Monitors SLA]
    ORCH --> BACKFILL[Backfills historical data]

    subgraph "DAG"
        A2[Ingest] --> B2[Clean]
        B2 --> C2[Aggregate]
        B2 --> D2[Train model]
        C2 --> E2[Load to DWH]
        D2 --> E2
    end
```

**Key principle**: Job outputs are immutable files. Each job reads its inputs and writes
new outputs. Never modify the input. This makes workflows debuggable, replayable, and
safe to re-run on failure.
