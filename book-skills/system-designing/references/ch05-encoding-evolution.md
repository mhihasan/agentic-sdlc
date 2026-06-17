# Chapter 5: Encoding and Evolution

## Core Thesis
Systems evolve. Code changes, but data written with old schemas outlives old code. Schema
evolution is not optional — it's a first-class engineering concern. The choice of encoding
format determines how safely and easily you can evolve your data model over time.

---

## Backward and Forward Compatibility

```mermaid
graph LR
    subgraph "Backward Compatibility"
        NC[New Code] -->|can read| OD[Old Data]
        note1[Safe to deploy new code<br/>without migrating all old data]
    end

    subgraph "Forward Compatibility"
        OC[Old Code] -->|can read| ND[New Data]
        note2[Safe to roll back to old code<br/>even if some new-format data exists]
    end
```

**Why both matter in rolling deployments**:

```mermaid
sequenceDiagram
    participant V1 as v1 node
    participant V2 as v2 node
    participant DB

    note over V1,V2: Rolling deployment — both versions live simultaneously
    V2->>DB: Write new-format record
    V1->>DB: Read record (must handle new format → forward compat)
    V1->>DB: Write old-format record
    V2->>DB: Read record (must handle old format → backward compat)
```

---

## Encoding Formats Compared

| Format | Schema? | Human-readable? | Binary? | Schema evolution | Size |
|--------|---------|----------------|---------|-----------------|------|
| JSON | Optional (JSON Schema) | ✅ Yes | ❌ | Weak | Large |
| XML | Optional (XSD) | ✅ Yes | ❌ | Weak | Very large |
| CSV | No | ✅ Yes | ❌ | Very weak | Medium |
| MessagePack | No | ❌ | ✅ | Weak | Small |
| Thrift / Protobuf | Required | ❌ | ✅ | Strong | Very small |
| Avro | Required (in/out of band) | ❌ | ✅ | Strong | Very small |

---

## Protocol Buffers (Protobuf) / Thrift

**Schema evolution via field tags**:

```protobuf
// v1 schema
message Person {
  required string user_name = 1;
  optional int64 favorite_number = 2;
}

// v2 schema — adding a field safely
message Person {
  required string user_name = 1;
  optional int64 favorite_number = 2;
  repeated string email = 3;    // new field — old code ignores unknown tags
}
```

```mermaid
graph LR
    subgraph "Wire format"
        B[Field tag: 3<br/>Type: string<br/>Value: 'alice@x.com']
    end

    OC[Old Code<br/>v1 schema] -->|sees tag=3, unknown| IGN[Ignores field safely]
    NC[New Code<br/>v2 schema] -->|sees tag=3| READS[Reads email field]
```

**Rules for safe Protobuf evolution**:
- ✅ Add optional/repeated fields with new tag numbers
- ✅ Remove optional/repeated fields (old writers send nothing, new readers get default)
- ❌ Change a field's data type (may break encoding)
- ❌ Change a field's tag number (existing data becomes unreadable)
- ❌ Add required fields (old writers don't send them → validation failure)

---

## Avro

Avro's key innovation: **writer's schema and reader's schema can differ** and are
reconciled at read time using explicit schema resolution rules.

```mermaid
graph LR
    W[Writer<br/>Schema v1] -->|binary data| F[File / Kafka message]
    F -->|binary data| R[Reader<br/>Schema v2]
    R -->|fetch writer schema| SR[Schema Registry<br/>or file header]
    SR -->|writer schema| R
    R -->|schema resolution rules| OUT[Reconciled output]
```

**Avro schema evolution rules**:
- Adding field with default: backward + forward compatible
- Removing field with default: backward + forward compatible  
- Changing type: only compatible if schemas define a union type

**Where to store the writer schema**:
1. Large file (Avro container): schema in file header
2. Database with many small records: schema version ID in each record → look up in registry
3. Kafka messages: Confluent Schema Registry — schema ID embedded in message

---

## Modes of Dataflow

### 1. Dataflow Through Databases

```mermaid
sequenceDiagram
    participant App_v1
    participant DB
    participant App_v2

    App_v1->>DB: Write record (old schema)
    note over DB: Data sits for months/years
    App_v2->>DB: Read record (must handle old schema → backward compat)
    App_v2->>DB: Write updated record (new schema → old code must be able to read → forward compat)
    App_v1->>DB: Read back (must handle new fields → forward compat)
```

**Data outlives code**. A field added years ago may still be read by code that knows nothing
about it. Always write code that gracefully ignores unknown fields.

### 2. Dataflow Through Services: REST and RPC

```mermaid
graph LR
    subgraph "REST"
        C1[Client] -->|HTTP GET /users/123| S1[Server]
        S1 -->|JSON response| C1
    end

    subgraph "RPC (gRPC / Thrift)"
        C2[Client<br/>generated stub] -->|Protobuf over HTTP/2| S2[Server<br/>generated skeleton]
        S2 -->|Protobuf response| C2
    end
```

**REST advantages**: Widely understood, human-readable, easy to debug, cacheable (HTTP caching),
no code generation required.

**RPC advantages**: Type safety, IDL-driven contract, smaller payload (binary), streaming
support (gRPC bidirectional streaming).

**The fundamental problem with RPC**: Network calls are not like local calls:
- Can fail in ways local calls cannot (timeout, packet loss, partial failure)
- Latency is variable and unpredictable
- Return values may not arrive even if the call succeeded (→ idempotency requirement)
- Cannot pass large objects by reference

**RPC evolution**: Must maintain backward-compatible request format (old clients, new server)
and forward-compatible response format (new server fields ignored by old clients).

### 3. Dataflow Through Message Queues

```mermaid
sequenceDiagram
    participant Producer
    participant Broker[Message Broker<br/>Kafka / SQS / RabbitMQ]
    participant Consumer_v1
    participant Consumer_v2

    Producer->>Broker: Message (schema v2)
    Broker->>Consumer_v1: Deliver (v1 consumer must handle v2 data → forward compat)
    Broker->>Consumer_v2: Deliver (v2 consumer handles v2 data)
    note over Producer,Consumer_v2: Different consumers may be at different versions simultaneously
```

---

## Service Discovery and Load Balancing

```mermaid
graph TD
    Client --> LB[Load Balancer]
    LB --> S1[Service Instance A]
    LB --> S2[Service Instance B]
    LB --> S3[Service Instance C]

    subgraph "Discovery Mechanisms"
        D1[DNS-based<br/>ELB, Route53]
        D2[Client-side<br/>Consul, Eureka<br/>client holds registry]
        D3[Service mesh<br/>Envoy, Istio<br/>sidecar proxy]
    end
```

---

## Durable Execution and Workflows (2nd Edition Addition)

Traditional RPC/REST: if the caller crashes mid-workflow, the state is lost. Durable execution
solves this by persisting workflow state so it can resume after any failure.

```mermaid
sequenceDiagram
    participant Code as Application Code
    participant Engine as Durable Execution Engine
    participant Storage as Persistent State Store

    Code->>Engine: Start workflow: order_fulfillment(order_id=42)
    Engine->>Storage: Checkpoint: step=1, order_id=42
    Engine->>Code: Execute step 1: reserve_inventory()
    Code-->>Engine: Done
    Engine->>Storage: Checkpoint: step=2, state={inventory_reserved}
    note over Engine: Crash / restart happens here
    Engine->>Storage: Reload checkpoint
    Engine->>Code: Resume from step 2: charge_payment()
    Code-->>Engine: Done
    Engine->>Storage: Checkpoint: step=3
    Engine->>Code: Execute step 3: send_confirmation()
```

**Key semantics**: Code appears to execute linearly, but the engine transparently saves state
after each step and can replay from any checkpoint after a crash.

**Examples**:
- **Temporal**: Open-source durable execution platform (used by DoorDash, Netflix, Stripe)
- **AWS Step Functions**: Managed state machine with Lambda steps
- **Azure Durable Functions**: Durable orchestration for Azure Functions
- **Conductor** (Netflix): Workflow orchestration platform

**How it relates to encoding**: Workflow state must be serialized to persistent storage at each checkpoint — schema evolution of workflow state is as important as database schema evolution.

---

## Event-Driven Architectures (Dataflow Through Events)

A third mode of dataflow (alongside databases and services): systems communicate by
publishing and subscribing to events asynchronously.

```mermaid
graph LR
    subgraph "Synchronous RPC"
        S1[Service A] -->|blocking HTTP call| S2[Service B]
        S2 -->|response| S1
        note1[Tight coupling: A waits for B<br/>B must be available<br/>Retry logic in A]
    end

    subgraph "Event-Driven"
        P[Service A] -->|publish event: OrderPlaced| BROKER[Message Broker<br/>Kafka / SQS]
        BROKER -->|subscribe| C1[Service B: Inventory]
        BROKER -->|subscribe| C2[Service C: Email]
        BROKER -->|subscribe| C3[Service D: Analytics]
        note2[A doesn't know about B,C,D<br/>Each service processes independently<br/>Can add new consumers without changing A]
    end
```

**Event-driven vs message-passing RPC**:
- Both use a message broker
- Event-driven: publisher doesn't care who processes the event (fire-and-forget, fanout)
- Message queue RPC: publisher sends to specific service, expects a response (request/reply pattern)

**Schema evolution for events**: Events in a broker are long-lived — consumers may be on older
versions. This makes Avro (with schema registry) the preferred encoding for Kafka events:
schema evolution is explicit and controlled. JSON works but provides no compile-time safety.

**Encoding/evolution rules apply to all dataflow modes**:

| Mode | Schema evolution concern |
|------|--------------------------|
| DB | Data outlives code — old records read by new code |
| RPC/REST | Rolling deploy — old client talks to new server |
| Message broker | Long message retention — old consumer reads new-format event |
| Durable workflow | State checkpointed and replayed — workflow schema must be backward-compatible |

---

## Schema Evolution Decision Framework

```mermaid
flowchart TD
    A{How is data shared?} -->|Internal services, polyglot| PB[Protobuf / gRPC<br/>Strong schema, code gen]
    A -->|Kafka event streaming| AV[Avro + Schema Registry<br/>Dynamic schema resolution]
    A -->|External / public APIs| REST[JSON REST<br/>JSON Schema optional<br/>Version via URL /v2/]
    A -->|Long-term storage, archival| AV2[Avro or Parquet<br/>Schema stored with data]
    A -->|Small team, internal only| JSON[JSON<br/>Acceptable if careful]
```

**The Merits of Schemas** (vs schema-less/JSON):
- Self-documentation: schema is the contract
- Compact encoding: no field names in payload
- Schema registry: audit trail of evolution
- Code generation: compile-time type safety
- Schema compatibility checks: catch breaking changes before deploy
