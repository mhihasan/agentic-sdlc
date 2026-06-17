---
name: generating-design-doc
description: >
  Use when the user wants to document an existing codebase as a structured
  architecture document. Triggers on "write an architecture doc", "create a
  design document for this system", "document this service", "generate a
  design doc from the codebase", "produce architectural diagrams from code",
  "do a system writeup", "create technical documentation with diagrams", or
  any request combining an existing codebase with an ask for structured
  architectural documentation. Do NOT use for greenfield design proposals
  (no code yet) or for short README-style summaries.
model: inherit
color: lightyellow
license: MIT
---

# Design Document Generator

Generates a single, production-grade architecture and design document for an existing system, grounded in its real codebase and any provided decision/context files.

## Required inputs

Before starting, you need:

1. **Codebase root** — a path to the repo or directory that contains the system being documented. This is the source of truth.
2. **System name** — what to call the system in the doc (usually the repo name, service name, or component name).
3. **Output path** — where to write the final Markdown file. If the user hasn't specified this, **ask once**: something like *"Where would you like the document written? Default is `<repo>/docs/architecture.md` if no preference."* If they decline to specify, use `<repo>/docs/architecture.md` and tell them that's where it landed.
4. **Decision/context files (optional)** — ADRs, RFCs, ticket history, prior docs, design notes. Read them if provided; their absence is fine.

If the user has provided 1, 2, and any optional 4 but not 3, ask for 3 once. Don't ask redundant questions about 1, 2, or 4 — proceed with what's given.

## Operating principles

Follow these rules throughout. They're the difference between a useful doc and a confabulated one.

1. **Ground every claim in code.** Do not invent components, flows, or integrations. If something is unclear after reading the code, mark it `[NEEDS VERIFICATION]` inline and list it in section 11. Never fabricate to fill a section. An honest gap is more valuable than fluent fiction — the reader will trust the doc more if uncertainty is visible.

2. **Names must match the code exactly.** Class names, module names, function names, table names, env vars, queue/topic names, file paths — all appear in the doc *exactly* as they appear in the repo. Casing, underscores, prefixes all preserved.

3. **Read before writing.** Start by mapping the repo: entry points, framework conventions, dependency manifests (`package.json`, `requirements.txt`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, etc.), IaC files (Terraform, CloudFormation, k8s manifests, Dockerfile, ECS task defs), CI workflows, and the decision file if provided. Build a mental model before producing any prose. A skipped reading phase produces a generic doc.

4. **Prefer specifics over generalities.** "Calls OpenAI `gpt-4o` via the `chat.completions` endpoint with retry-on-429" beats "calls an LLM." "8 vCPU / 16 GB Fargate task" beats "scalable compute." If you can't be specific, mark it `[NEEDS VERIFICATION]` rather than hedging.

5. **Diagrams must be syntactically valid Mermaid.** Every diagram block must parse. Quote node labels containing spaces, slashes, parens, colons, or special characters. Use `\n` inside quoted strings for multi-line labels. Don't use the word `end` as a class name in sequence diagrams — Mermaid treats it as a keyword.

6. **Length is not a goal.** A section with nothing to say should be one honest sentence ("No retries are implemented; failures surface to the caller.") not padded prose. A short section that's accurate beats a long section that's invented.

7. **No marketing language.** No "robust," "seamless," "leverages," "powerful," "cutting-edge," "best-in-class." Engineering tone only. The reader is a senior engineer; they want signal.

8. **Tense and voice.** Present tense, active voice, describing the system as it exists today. Not as it might be, should be, or used to be.

## Process

Follow these phases in order. Don't write any section before you've done the reading phase.

### Phase 1: Inventory

Read the repo root, the decision file (if provided), and any READMEs. Identify:

- Language, framework, runtime (Lambda, ECS, k8s, long-running service, library)
- Entry points (main, handler, route definitions)
- Primary domain modules and shared base classes
- External dependencies — both from package manifests and from actual import statements (manifests can be stale or aspirational)
- IaC / deployment manifests for sizing and topology
- Decision file: what's documented, what's contradicted by code, what's silent

Produce a brief internal map (a few sentences to yourself) before writing.

### Phase 2: Trace one happy path

Pick the simplest invocation flow and walk it end-to-end through the code, noting every collaborator and every external call. This becomes the spine of the data flow diagram (section 3) and the first sequence diagram (section 4).

### Phase 3: Enumerate variants

Identify each distinct execution path — handler class, event type, route, job type, document type, command, whatever the dispatch unit is. Each gets its own sequence diagram in section 4. If a system has many similar variants that differ only in input shape, group them and note the grouping rather than producing 30 near-identical diagrams.

### Phase 4: Map the dispatch layer

Find where the entry point routes to variants. This grounds section 1's architecture diagram and section 5's dispatch-pattern bullet.

### Phase 5: Cross-reference decisions vs code

For each documented decision in the decision file, confirm it's still reflected in code. For each non-trivial pattern in code, check whether it's documented. Drift between the two is interesting — flag it.

### Phase 6: Identify gaps

Anything you can't ground in code or the decision file goes in section 11. Sizing numbers you can't find in IaC, SLOs you can't find in monitoring config, retry policies you can't find in code — all gaps.

### Phase 7: Write the doc

Sections 0–11, in order. Diagrams before their prose where it helps. Then a self-review pass before delivering.

## Required document structure

Produce the following sections in this order. The example structure is the canonical shape — diagram counts adapt to the system, but section presence does not.

### Section 0 — Title and one-paragraph summary

```
# <SYSTEM_NAME> Architecture

<2–4 sentences: what it is, what triggers it, what it produces, where it sits in the larger system. Mention the runtime (Lambda, ECS task, library, etc.) and the primary upstream and downstream.>
```

### Section 1 — Architecture Diagram

A single Mermaid `graph TD` showing the full system decomposed into layers. Use `subgraph` blocks for layering. Typical layers (adapt to what the system actually has — don't force layers that aren't there):

- Trigger layer (what invokes this)
- Entry point / dispatcher
- Core business logic / domain layer
- Shared base classes or utilities
- Local modules
- SDK or shared-library abstraction layer
- External services

Edges show real call relationships found in code. Group external services in their own subgraph at the bottom.

### Section 2 — Infrastructure Diagram

A single Mermaid `graph LR` showing the deployment topology: image registry → compute → networking boundaries (VPC/subnet/SG) → IAM → secrets → data stores → observability. Include actual compute sizing (vCPU/memory, instance type, Lambda memory, replica count) if discoverable from IaC or deployment manifests. If not discoverable, omit and note as `[NEEDS VERIFICATION]` — don't guess.

### Section 3 — Data Flow Diagram

A single Mermaid `graph TD` tracing one end-to-end request: input arrival → each processing phase → final output and side effects. Each node is a phase, not a function. Annotate nodes with the data shape entering and leaving.

### Section 4 — Sequence Diagrams

One Mermaid `sequenceDiagram` per distinct execution path. For each:

- One-paragraph intro: what subclass/handler/route this is, what makes it different from the others, why it exists.
- Participants must be named consistently with section 1.
- Use `par`/`and` for actual concurrency (`asyncio.gather`, `Promise.all`, `errgroup`, parallel goroutines).
- Use `alt`/`else` for actual branching in code, not hypothetical "could happen" flows.
- Use `loop` for actual iteration over collections.
- Use `Note over X,Y: ...` to flag where an upstream pipeline runs unchanged before this path diverges.

### Section 5 — Key Design Decisions

Bulleted list. Each bullet is **bold lead-in followed by 2–4 sentences of justification grounded in code or the decision file**. Cover at minimum:

- Concurrency model and why (async vs threads vs processes, gather patterns, parallelism limits)
- Dispatch / extension pattern (strategy map, factory, plugin registry — why this over `if/elif`)
- Shared base classes or composition pattern — what they own, what subclasses override
- Observability stack — logging, tracing, error reporting, structured log fields, correlation IDs
- Resource sizing — vCPU/memory/replicas and why those numbers
- Abstraction boundaries — what gets called directly vs through an SDK/client layer
- Output/persistence model — what produces the final artifact, where it's stored, how downstream consumers read it

Add more bullets if the system has other significant decisions worth surfacing.

### Section 6 — Trade-offs and Alternatives Considered

For each major decision in section 5, list:

- **Trade-off**: what this design gives up.
- **Alternative**: what else was viable.
- **Why rejected**: grounded in the decision file or in code constraints (existing infra, cost, latency, team familiarity).

If the decision file and codebase don't reveal an alternative for a given decision, write "No alternative documented in source material" — do not invent one.

### Section 7 — Non-Functional Requirements and Operational Characteristics

Cover what's actually present or configured. Omit subsections where there's nothing in the codebase to point at — do not invent SLOs to fill space.

- **Scaling**: horizontal (replicas, task count) vs vertical (sizing). Autoscaling triggers if configured.
- **Latency / throughput**: documented targets if any; measured characteristics from code (timeouts, batch sizes, rate limits).
- **Availability**: redundancy, multi-AZ, retry policies, idempotency guarantees.
- **Cost drivers**: the top 3 cost contributors (compute hours, LLM tokens, third-party API quota, egress) based on actual code paths.
- **Security and data classification**: PII/PHI/regulated data handled, secrets management, network boundaries, authn/authz to upstream and downstream.
- **Observability**: log destinations, metric names, traces, alerting (only what's wired up in code/IaC).

### Section 8 — Failure Modes and Recovery

Table or bulleted list. For each failure mode that has a real codepath:

- **Failure**: what goes wrong (upstream timeout, malformed input, LLM 429, DB unreachable, S3 write failure).
- **Detection**: how it surfaces (Sentry tag, log line, metric, alert).
- **Behavior**: what the system does today (retry with backoff, dead-letter, fail-fast, partial success).
- **Recovery**: manual steps, or "automatic on next invocation."

Do not invent hypothetical disasters.

### Section 9 — Upstream and Downstream Integrations

For each integration:

- **Direction**: upstream (calls this system) or downstream (this system calls it).
- **Contract**: payload shape, transport (HTTP/gRPC/SQS/S3/DB), authn.
- **Coupling**: synchronous, async, fire-and-forget, request-response.
- **Failure semantics**: what happens to this system if the other is down.
- **Where it lives in code**: file path or module reference.

### Section 10 — Concerns, Known Issues, and Technical Debt

What an engineer joining this system should know that isn't obvious from the diagrams. Grounded in:

- TODO/FIXME/HACK/XXX comments in the codebase
- The decision file's open-items section if it has one
- Patterns that work but show stress (long methods, deep inheritance, shared mutable state, missing tests on critical paths)
- Integrations that are fragile (no retry, no timeout, no circuit breaker)

Be specific. "`OrderProcessor.handle_payment()` is 280 lines and mixes I/O with validation logic" is useful; "code quality could improve" is not.

### Section 11 — Open Questions and Items Needing Verification

A bulleted list of every `[NEEDS VERIFICATION]` marker from earlier sections, plus anything you couldn't determine from the source material. For each, state what you'd need to confirm it — a specific file, a person, a runtime check.

An empty section 11 on a non-trivial system is itself a red flag. If it ends up empty, re-check whether you actually grounded everything or just glossed over uncertainty.

## Diagram conventions

- Quote any node label containing spaces, slashes, parens, colons: `NODE["my service / v2"]`.
- Multi-line labels use `\n` inside the quoted string.
- Subgraphs are named: `subgraph trigger["Trigger Layer"]`.
- External services subgraph goes last in `graph TD` diagrams.
- Sequence-diagram participant names match the class/module/service names used elsewhere in the doc.
- Prefer `graph TD` for architecture and data flow; `graph LR` for infrastructure topology.
- Don't use Mermaid-reserved words (`end`, `subgraph`, `class`, `state`, `note`) as bare node identifiers — quote them or rename.

## Self-review checklist

**STOP before delivering the document.** Run this checklist — if any item fails, fix it before output:

- [ ] Every Mermaid block parses (mentally trace each one — opening/closing, quoted labels, valid arrow syntax).
- [ ] Every class/module/service name in the doc exists in the codebase.
- [ ] No section contains invented content. Anything uncertain is marked `[NEEDS VERIFICATION]`.
- [ ] Section 11 lists every uncertainty raised in sections 0–10.
- [ ] An engineer who has never seen this system could read the doc and answer: *what triggers it, what it does, what it calls, what calls it, how it scales, how it fails, and what's risky about it.*
- [ ] Length is justified by content, not padding.

## Delivery

Write the document to the output path. After writing, print a brief summary in chat:

1. What you covered (number of variants documented, diagrams produced).
2. What you couldn't ground — count of `[NEEDS VERIFICATION]` items and a one-line description of the highest-risk gaps.
3. What you'd recommend reviewing first if the user wants to sanity-check the doc.

Do not paste the full document into chat — the file is the deliverable. Tell the user the output path.

## Common failure modes to avoid

- **Confabulated sizing.** Don't write "runs on a t3.medium" or "scales to 100 RPS" unless you found it in IaC, monitoring config, or the decision file. Mark `[NEEDS VERIFICATION]` instead.
- **Over-decomposition.** A system with 30 nearly identical handlers does not need 30 sequence diagrams. Group by behavioral equivalence and note the grouping.
- **Diagram for diagram's sake.** If section 3 (data flow) would just restate section 1 (architecture), simplify section 3 to focus on the data shape transitions and let section 1 carry the structural view.
- **Decision file taken as gospel.** Decision files drift from code. If the code contradicts the decision file, document what the code does and flag the drift in section 10.
- **Missing the "why."** A doc that lists what the system does without explaining why it's built that way is a map without a legend. Section 5 carries this load — don't shortchange it.
- **Padding section 7.** If the system has no documented SLOs, no autoscaling, no formal cost tracking — say so in one sentence per subsection and move on. Don't manufacture numbers.
