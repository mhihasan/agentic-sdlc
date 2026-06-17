# Clean Architecture — Book Overview

**Author:** Robert C. Martin ("Uncle Bob") | **Publisher:** Prentice Hall | **Year:** 2017

**Problem:** Software teams consistently produce systems that start fast and slow to a crawl. Cost per feature grows with every release even as effort increases. The root cause is not lack of talent — it is architecture that conflates business rules with frameworks, databases, and UI.

**Thesis:** Good architecture minimises the human resources required to build and maintain a system. The mechanism: keep source-code dependencies pointing only inward, toward high-level business policy and away from all volatile details.

---

## Part I — Introduction

**chapter-01-what-is-design-and-architecture.md**
Design and architecture are the same thing viewed at different altitudes — both describe decisions that shape the system. The only measure of quality is economics: does the cost of change stay low? Martin presents real productivity data showing how a typical codebase collapses from high velocity to near-zero over several releases, even as headcount grows.

**chapter-02-a-tale-of-two-values.md**
Software has two values: behavior (what it does now) and structure (how easy it is to change). Behavior is urgent; structure is important. Developers consistently sacrifice structure for behavior. Architects must actively fight to preserve structure — it is the harder-to-recover value.

---

## Part II — Programming Paradigms

**chapter-03-paradigm-overview.md**
Three paradigms — structured, object-oriented, functional — each *removed* a dangerous capability: goto, unrestricted function pointers, and assignment respectively. Paradigms impose discipline. All three contribute to clean architecture.

**chapter-04-structured-programming.md**
Dijkstra proved goto makes programs unprovable. Structured control flow (sequence, selection, iteration) enables functional decomposition and testability. Software's answer to scientific falsifiability: we cannot prove programs correct, but we can prove them incorrect through tests.

**chapter-05-object-oriented-programming.md**
OOP's unique contribution is *safe polymorphism* — pointer indirection without the danger of arbitrary function pointers. This enables Dependency Inversion: source-code dependencies can point against the flow of control, enabling plugin architectures where high-level policy is protected from low-level detail.

**chapter-06-functional-programming.md**
Immutability eliminates an entire class of concurrency bugs. Event sourcing — storing transactions rather than mutable state — allows full state reconstruction from a log and scales without locking.

---

## Part III — SOLID Design Principles

**chapter-07-srp-single-responsibility-principle.md**
SRP is not "do one thing." It means: one module, one actor (business stakeholder). When Finance and HR both own `Employee`, a change for Finance breaks HR. Split by actor.

**chapter-08-ocp-open-closed-principle.md**
Systems should be open for extension, closed for modification. Add new behavior by writing new code, never by editing tested existing code. Achieved via polymorphism and unidirectional dependency hierarchies.

**chapter-09-lsp-liskov-substitution-principle.md**
Subtypes must be fully substitutable for their base types. Violations force callers to use `isinstance()` checks — coupling to concrete types. Extends to REST APIs: all implementations of a service contract must honour it identically.

**chapter-10-isp-interface-segregation-principle.md**
Do not depend on methods you do not use. Fat interfaces force clients to recompile/redeploy when irrelevant methods change. Split into narrow, role-specific interfaces.

**chapter-11-dip-dependency-inversion-principle.md**
High-level policy must not depend on low-level detail. Both depend on abstractions. DIP is the foundational mechanism for all boundary crossing in Clean Architecture. The interface lives in the high-level layer; the concrete implementation lives in the low-level layer.

---

## Part IV — Component Principles

**chapter-12-components.md**
Components are independently deployable units (packages, JARs, services). Stable public interfaces enable consumers to depend on them without coupling to internal implementation.

**chapter-13-component-cohesion.md**
Three forces: REP (release granule = reuse granule), CCP (things that change together belong together — component-level SRP), CRP (don't force dependencies on unused things — component-level ISP). These form a tension triangle; balance shifts with project maturity.

**chapter-14-component-coupling.md**
ADP: no cycles in the component dependency graph. SDP: depend in the direction of stability (I metric = fan-out / (fan-in + fan-out)). SAP: stable components must be abstract. Components should cluster near the main sequence (A + I ≈ 1).

---

## Part V — Architecture

**chapter-15-what-is-architecture.md**
Architecture is about supporting use cases while deferring irreversible decisions as long as possible. The database, framework, and UI are all details — they should not constrain the core. Good architecture leaves options open.

**chapter-16-independence.md**
Good architecture supports independent develop-ability (teams don't block each other), independent deployability (components ship separately), and independent operation. Decoupling modes: source-level, deployment-level, service-level.

**chapter-17-boundaries-drawing-lines.md**
Boundaries separate things that change at different rates for different reasons. Draw lines between policy (business rules) and details (databases, UI, frameworks). The database is not at the center — it is behind a boundary.

**chapter-18-boundary-anatomy.md**
Three boundary types: monolith (cheap, function calls), process (sockets/pipes), service (network). Each adds communication cost. A monolith can have clean architectural boundaries; a microservices fleet can have none. Topology is not architecture.

**chapter-19-policy-and-level.md**
Level = distance from I/O. High-level policies (core business rules) are far from inputs and outputs. Source-code dependencies must always flow from low-level (close to I/O) toward high-level (far from I/O).

**chapter-20-business-rules.md**
Two types: Critical Business Rules (Entities — pure domain logic, exists without software) and Application Business Rules (Use Cases — orchestration for a specific scenario). Entities are the most stable, innermost ring. Use Cases know Entities and interfaces; nothing else.

**chapter-21-screaming-architecture.md**
The top-level directory structure should scream the business domain, not the framework. "Healthcare System," not "Rails App." Use cases are first-class citizens. Frameworks are tools in the outer ring.

**chapter-22-the-clean-architecture.md**
The synthesis: four concentric rings — Entities, Use Cases, Interface Adapters, Frameworks & Drivers. The Dependency Rule: source-code dependencies point only inward. Data crossing boundaries must be translated into simple structures (DTOs); never pass framework objects or ORM entities across rings.

**chapter-23-presenters-and-humble-objects.md**
Humble Object pattern: split testable logic from hard-to-test presentation at every boundary. Presenters format data for display but contain no business logic; Views are dumb. This pattern appears at every architectural boundary.

**chapter-24-partial-boundaries.md**
Full boundaries are expensive to build and maintain. Three partial strategies: skip-the-last-step (build infrastructure, deploy as one), one-dimensional (only one side of the interface), facade (over a subsystem). Invest incrementally.

**chapter-25-layers-and-boundaries.md**
Even simple systems have more architectural boundaries than expected. The challenge is identifying which to implement fully, which partially, and which to defer. Over-engineering boundaries is as costly as under-engineering them.

**chapter-26-the-main-component.md**
Main is the dirtiest, most concrete component in the system. It creates and wires everything together. Main is a plugin to the application — different Main components can configure the system for production, test, or development without touching business logic.

**chapter-27-services-great-and-small.md**
Services are not inherently architecturally significant. Services that share databases or DTOs are still coupled — they are a distributed monolith. Clean Architecture applies within each service. The Kitty Problem: a cross-cutting feature that forces changes in 5 services simultaneously reveals those services are not truly decoupled.

**chapter-28-the-test-boundary.md**
Tests are the outermost architectural ring. The Fragile Tests Problem: tests coupled to implementation details break with every refactor, making developers fear change. Design for testability using the same abstraction boundaries as production. A test-specific API lets tests bypass GUI and DB entirely.

**chapter-29-clean-embedded-architecture.md**
Hardware is a detail. HAL (Hardware Abstraction Layer) and OSAL (OS Abstraction Layer) allow business logic to run on multiple processors and operating systems. The same Clean Architecture principles apply — the target hardware bottleneck is eliminated by DIP.

---

## Part VI — Details

**chapter-30-the-database-is-a-detail.md**
The database is an I/O device. The data model matters; the database engine (PostgreSQL, MySQL, MongoDB) does not. Use Cases interact with data via Repository interfaces — never via SQL or ORM queries directly in business logic.

**chapter-31-the-web-is-a-detail.md**
The Web is a GUI — an I/O device. It has oscillated between thin-client and thick-client repeatedly. Architecture built around the Web is fragile. Core use cases must be deliverable via any interface technology.

**chapter-32-frameworks-are-details.md**
Frameworks are powerful but ask you to marry them — to let their conventions dictate your architecture. Treat frameworks as tools: use them at the outer ring, never let them colonise your domain or use cases. Keep framework code at arm's length behind interfaces.

**chapter-33-case-study-video-sales.md**
Full worked example: online video sales system. Steps: identify actors → enumerate use cases → derive component structure → draw boundaries → assign components to rings. Demonstrates Clean Architecture derivation from first principles.

**chapter-34-the-missing-chapter.md** *(Simon Brown)*
The gap between theory and practice. Four packaging strategies: package-by-layer (anti-pattern), package-by-feature (better), ports-and-adapters/hexagonal (good), package-by-component (Brown's synthesis). Architecture decays without structural enforcement — access modifiers and tooling (dependency-cruiser, ArchUnit) must enforce boundaries.

---

## Top 15 Key Concepts

1. **Dependency Rule** — source-code dependencies point only inward (Ch 22)
2. **Four Rings** — Entities → Use Cases → Interface Adapters → Frameworks & Drivers (Ch 22)
3. **DIP** — high-level policy and low-level detail both depend on abstractions (Ch 11)
4. **SRP** — one module, one actor, one reason to change (Ch 7)
5. **Entities** — Critical Business Rules encoded in pure domain objects (Ch 20)
6. **Use Cases** — Application-specific orchestration of entities (Ch 20)
7. **Humble Object** — split testable logic from hard-to-test I/O at every boundary (Ch 23)
8. **ADP** — no cycles in component graph; cycles = morning-after syndrome (Ch 14)
9. **SDP** — depend in the direction of stability (Ch 14)
10. **CCP** — things that change together belong together (Ch 13)
11. **Architecture = deferral** — maximise undecided decisions; details come later (Ch 15)
12. **Database is a detail** — Repository interface hides persistence technology (Ch 30)
13. **Screaming Architecture** — top-level structure reveals domain, not framework (Ch 21)
14. **Main as plugin** — Main wires the system; business logic never sees Main (Ch 26)
15. **Package-by-component** — coarse-grained components enforce boundaries in code (Ch 34)
