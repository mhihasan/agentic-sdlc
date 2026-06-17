---
name: system-designing
description: >
  Expert system design skill grounded in "Designing Data-Intensive Applications" (2nd Edition)
  by Kleppmann & Riccomini. Use for: distributed systems design, storage internals, replication,
  sharding, transactions, consistency, stream/batch processing, and architecture trade-offs.
  Trigger for: "help me design a system", "how does X database work", "explain ACID/BASE",
  "what is linearizability", "explain CAP theorem", "how does Kafka work", "LSM trees vs B-trees",
  "design a URL shortener / rate limiter / message queue", "trade-offs between X and Y architectures",
  system design interviews, HLD, LLD, or scalability challenges. Always use this skill over
  memory for system design and DDIA topics.
---

# System Design — Expert Reference Skill (DDIA-grounded)

This skill is grounded in DDIA 2nd Edition (Kleppmann & Riccomini). Each chapter has a
dedicated reference file. **Read the relevant file(s) before answering** — do not rely on
memory for specifics. Multiple chapters may apply to a single question.

## Chapter Index & Routing Guide

| File | Chapter | Use When Asking About |
|------|---------|----------------------|
| `references/ch01-tradeoffs-architecture.md` | Ch 1: Trade-Offs in Data Systems Architecture | OLTP vs OLAP, data warehouses, data lakes, cloud vs self-hosting, microservices, system categories |
| `references/ch02-nonfunctional-requirements.md` | Ch 2: Defining Nonfunctional Requirements | Reliability, scalability, maintainability, latency percentiles, fault tolerance, load testing |
| `references/ch03-data-models-query-languages.md` | Ch 3: Data Models and Query Languages | Relational vs document vs graph models, SQL, normalization, joins, schema design |
| `references/ch04-storage-retrieval.md` | Ch 4: Storage and Retrieval | LSM-trees, B-trees, SSTables, indexes, column-oriented storage, data warehouses internals |
| `references/ch05-encoding-evolution.md` | Ch 5: Encoding and Evolution | Protobuf, Avro, JSON schema, backward/forward compatibility, schema evolution, RPC, REST |
| `references/ch06-replication.md` | Ch 6: Replication | Leader/follower replication, failover, replication lag, multi-leader, conflict resolution |
| `references/ch07-sharding.md` | Ch 7: Sharding | Partitioning strategies, hot spots, consistent hashing, secondary indexes, rebalancing |
| `references/ch08-transactions.md` | Ch 8: Transactions | ACID, isolation levels, MVCC, serializability, lost updates, 2PL, 2PC, distributed transactions |
| `references/ch09-trouble-distributed-systems.md` | Ch 9: The Trouble with Distributed Systems | Network faults, clock skew, process pauses, Byzantine faults, timeouts |
| `references/ch10-consistency-consensus.md` | Ch 10: Consistency and Consensus | Linearizability, CAP theorem, logical clocks, Paxos/Raft, ZooKeeper, total order broadcast |
| `references/ch11-batch-processing.md` | Ch 11: Batch Processing | MapReduce, dataflow engines (Spark/Flink), HDFS, joins in batch, workflow orchestration |
| `references/ch12-stream-processing.md` | Ch 12: Stream Processing | Kafka, message brokers, CDC, event sourcing, stream joins, stateful processing, watermarks |
| `references/ch13-philosophy-streaming-systems.md` | Ch 13: A Philosophy of Streaming Systems | Unbundling databases, derived data, lambda/kappa architecture, end-to-end correctness |
| `references/ch14-doing-right-thing.md` | Ch 14: Doing the Right Thing | Ethics, privacy, GDPR, bias in ML, feedback loops, surveillance, data governance |

## Multi-Chapter Routing

Some questions span multiple chapters. Common combinations:

- **"Design a real-time analytics pipeline"** → Ch1 + Ch4 + Ch12 + Ch13
- **"How does a distributed database handle failures?"** → Ch6 + Ch8 + Ch9 + Ch10
- **"Compare Kafka vs RabbitMQ"** → Ch12 (primary) + Ch13
- **"Should I use NoSQL or SQL?"** → Ch3 + Ch1 + Ch4
- **"How does Google Spanner / TrueTime work?"** → Ch9 + Ch10
- **"Explain event sourcing and CQRS"** → Ch12 + Ch13
- **"Design a social media feed system"** → Ch2 + Ch6 + Ch7 + Ch12
- **"What are the consistency guarantees of DynamoDB?"** → Ch8 + Ch10
- **"How to handle schema migrations in a live system?"** → Ch5 + Ch13

## Usage Instructions

1. Identify the question domain using the routing table above
2. Read the relevant reference file(s)
3. Synthesize an answer grounded in the book's concepts
4. Use Mermaid diagrams in your answer when architecture or data flow is involved
5. Cite trade-offs explicitly — DDIA is fundamentally a book about trade-offs
6. For code examples, use Python unless otherwise specified (matches Hasanul's stack)
