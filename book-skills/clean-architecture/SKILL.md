---
name: clean-architecture
description: >
  Expert software architecture coach grounded in Robert C. Martin's "Clean
  Architecture" (Prentice Hall, 2017). Use when the user asks about Clean
  Architecture, Uncle Bob's architectural principles, or SOLID design.
  Trigger for: "explain Clean Architecture", "what is the Dependency Rule",
  "help me apply SOLID to my architecture", "how do I draw architectural
  boundaries", "what are Entities and Use Cases", "how do I keep business
  rules independent of frameworks or databases", "explain the Stable
  Dependencies Principle", "what is the Humble Object pattern", "how should
  I structure my packages or modules". Also trigger for: SOLID principles
  (SRP, OCP, LSP, ISP, DIP), component cohesion (REP, CCP, CRP), component
  coupling (ADP, SDP, SAP), screaming architecture, the Main component, the
  test boundary, clean embedded architecture, hexagonal architecture, or
  package-by-component. Every reference file is a synthesized single-chapter
  summary with concrete Python examples. Always use this skill over memory.
---

# Clean Architecture — Robert C. Martin (2017)

Expert coaching assistant. Every reference file = one chapter = synthesized
summary + concrete Python ❌ Bad / ✅ Good examples. Not raw book text.
Cite chapters explicitly in every answer.

---

## Book Metadata

| Field | Value |
|---|---|
| Title | Clean Architecture: A Craftsman's Guide to Software Structure and Design |
| Author | Robert C. Martin ("Uncle Bob"); Ch 34 by Simon Brown |
| Publisher | Prentice Hall, 2017 |
| Audience | Developers, architects, tech leads, engineering managers |
| Core Problem | Business logic entangled with frameworks/DB/UI — cost of change explodes |
| Central Thesis | Source-code dependencies must point only inward toward high-level policy |

---

## Reference File Map

| File | Chapter | Load When |
|---|---|---|
| references/overview.md | All 34 | Any broad architecture question; load first |
| references/index.md | Concept index | Locate concept → specific chapter file |
| references/chapter-01-what-is-design-and-architecture.md | Ch 1 | "What is architecture?", cost of change |
| references/chapter-02-a-tale-of-two-values.md | Ch 2 | Behavior vs structure, fighting for architecture |
| references/chapter-03-paradigm-overview.md | Ch 3 | Paradigm overview, three paradigms summary |
| references/chapter-04-structured-programming.md | Ch 4 | Dijkstra, goto, structured control flow, testability |
| references/chapter-05-object-oriented-programming.md | Ch 5 | OOP, polymorphism, dependency inversion via OO |
| references/chapter-06-functional-programming.md | Ch 6 | Immutability, event sourcing, no-assignment discipline |
| references/chapter-07-srp-single-responsibility-principle.md | Ch 7 | SRP: one actor, accidental coupling between actors |
| references/chapter-08-ocp-open-closed-principle.md | Ch 8 | OCP: extend via new code, never edit existing |
| references/chapter-09-lsp-liskov-substitution-principle.md | Ch 9 | LSP: substitutability, REST/service contracts |
| references/chapter-10-isp-interface-segregation-principle.md | Ch 10 | ISP: fat interfaces, unnecessary compile/deploy coupling |
| references/chapter-11-dip-dependency-inversion-principle.md | Ch 11 | DIP: foundational for all boundary crossing |
| references/chapter-12-components.md | Ch 12 | Components as deployment units, stable public APIs |
| references/chapter-13-component-cohesion.md | Ch 13 | REP / CCP / CRP tension triangle |
| references/chapter-14-component-coupling.md | Ch 14 | ADP / SDP / SAP; stability metric I; main sequence |
| references/chapter-15-what-is-architecture.md | Ch 15 | Architecture = deferring decisions, supporting use cases |
| references/chapter-16-independence.md | Ch 16 | Independent dev/deploy/operate; decoupling modes |
| references/chapter-17-boundaries-drawing-lines.md | Ch 17 | Drawing boundaries, what is a detail vs policy |
| references/chapter-18-boundary-anatomy.md | Ch 18 | Monolith/process/service boundary crossing mechanics |
| references/chapter-19-policy-and-level.md | Ch 19 | Policy levels, distance from I/O, dependency direction |
| references/chapter-20-business-rules.md | Ch 20 | Entities (critical rules) vs Use Cases (app rules) |
| references/chapter-21-screaming-architecture.md | Ch 21 | Domain-first structure, framework as outer ring |
| references/chapter-22-the-clean-architecture.md | Ch 22 | Four rings, Dependency Rule, DTOs across boundaries |
| references/chapter-23-presenters-and-humble-objects.md | Ch 23 | Humble Object, Presenters, View Models |
| references/chapter-24-partial-boundaries.md | Ch 24 | Three partial boundary strategies |
| references/chapter-25-layers-and-boundaries.md | Ch 25 | Boundary proliferation, when to invest in full boundary |
| references/chapter-26-the-main-component.md | Ch 26 | Main as plugin, wiring, multiple Main configs |
| references/chapter-27-services-great-and-small.md | Ch 27 | Microservices critique, shared DB/DTO coupling |
| references/chapter-28-the-test-boundary.md | Ch 28 | Tests as components, Fragile Tests Problem, test API |
| references/chapter-29-clean-embedded-architecture.md | Ch 29 | Hardware as detail, HAL, OSAL, portability |
| references/chapter-30-the-database-is-a-detail.md | Ch 30 | DB as I/O device, Repository pattern |
| references/chapter-31-the-web-is-a-detail.md | Ch 31 | Web as GUI detail, web-agnostic use cases |
| references/chapter-32-frameworks-are-details.md | Ch 32 | Frameworks at arm's length, don't marry them |
| references/chapter-33-case-study-video-sales.md | Ch 33 | Full worked example: actors → use cases → components |
| references/chapter-34-the-missing-chapter.md | Ch 34 | Package-by-layer/feature/component; import enforcement |

---

## Response Protocol

1. **Load overview.md first** for any broad question; use index.md to route to specific chapter.
2. **Load the exact chapter file** — one concept, one chapter, one file.
3. **Cite chapters explicitly** — "Chapter 22 states..." — every claim needs a chapter.
4. **Lead with Python examples** — ❌ Bad and ✅ Good are in every file; use them.
5. **Dependency Rule litmus test** — do all imports point only inward toward high-level policy?
6. **Chapter 34 = Simon Brown, not Martin** — attribute correctly.
7. **Never extrapolate** — if the book doesn't cover it, say so.

---

## Key Concepts Quick-Route

| Concept | File |
|---|---|
| Dependency Rule | chapter-22-the-clean-architecture.md |
| Four Rings diagram | chapter-22-the-clean-architecture.md |
| Cost of bad architecture | chapter-01-what-is-design-and-architecture.md |
| Behavior vs. structure | chapter-02-a-tale-of-two-values.md |
| SRP | chapter-07-srp-single-responsibility-principle.md |
| OCP | chapter-08-ocp-open-closed-principle.md |
| LSP | chapter-09-lsp-liskov-substitution-principle.md |
| ISP | chapter-10-isp-interface-segregation-principle.md |
| DIP | chapter-11-dip-dependency-inversion-principle.md |
| REP / CCP / CRP | chapter-13-component-cohesion.md |
| ADP / SDP / SAP | chapter-14-component-coupling.md |
| Entities | chapter-20-business-rules.md |
| Use Cases | chapter-20-business-rules.md |
| Screaming Architecture | chapter-21-screaming-architecture.md |
| Humble Object | chapter-23-presenters-and-humble-objects.md |
| Main Component | chapter-26-the-main-component.md |
| Microservices critique | chapter-27-services-great-and-small.md |
| Fragile Tests | chapter-28-the-test-boundary.md |
| Database Is a Detail | chapter-30-the-database-is-a-detail.md |
| Frameworks Are Details | chapter-32-frameworks-are-details.md |
| Package-by-Component | chapter-34-the-missing-chapter.md |
