# Dive Into Design Patterns — Overview

**Author:** Alexander Shvets | **Publisher:** Refactoring.Guru | **Year:** 2022

**Problem:** Object-oriented codebases become increasingly brittle and expensive to change as
they grow — classes accumulate responsibilities, dependencies tangle, and adding features
breaks existing behaviour. Developers repeatedly solve the same structural and communication
problems from scratch.

**Thesis:** 22 classic GoF design patterns, when applied with understanding of their intent
and trade-offs, provide proven, named solutions to recurring software design problems — enabling
systems that are extensible, maintainable, and comprehensible to any engineer who shares the
vocabulary.

---

## Chapter Summaries

**chapter-01-oop-intro.md**
Establishes the four OOP pillars (Abstraction, Encapsulation, Inheritance, Polymorphism) and
the six object relation types (dependency, association, aggregation, composition, implementation,
inheritance). These are the vocabulary and building blocks for understanding every pattern in
the book. Key insight: composition is almost always preferable to inheritance beyond one level.

**chapter-02-patterns-intro.md**
Defines what a design pattern is (a reusable solution template, not copy-paste code) and
introduces the three GoF families: Creational, Structural, Behavioural. Explains why patterns
matter as a shared vocabulary for teams and a catalogue of solved problems. Cautions against
over-application — patterns add indirection and should only be applied when the problem
genuinely warrants the complexity.

**chapter-03-design-principles.md**
Three foundational principles precede SOLID: Encapsulate What Varies (isolate change behind
an interface), Program to an Interface Not Implementation (depend on abstractions), and Favour
Composition Over Inheritance (build behaviour by combining objects rather than subclassing).
These principles directly motivate the patterns that follow.

**chapter-04-solid-principles.md**
Five principles — SRP, OCP, LSP, ISP, DIP — that together define what good OO design looks
like. SRP limits reasons to change; OCP enables extension without mutation; LSP enforces
substitution contracts; ISP keeps interfaces lean; DIP points dependencies toward abstractions.
Violating any one principle creates compounding technical debt.

**chapter-05-factory-method.md**
Defines an interface for creating objects in a base class, letting subclasses choose the
concrete type. The canonical solution when the type of product must vary by subclass or
configuration. Eliminates `new ConcreteType()` calls scattered in client code.

**chapter-06-abstract-factory.md**
Creates families of related objects without specifying their concrete classes. Guarantees that
products from the same family are used together consistently. Solves the combinatorial class
explosion when products have multiple variant families (themes, platforms, providers).

**chapter-07-builder.md**
Constructs complex objects step-by-step through a fluent interface, separating construction
logic from the product's representation. Solves the telescoping constructor anti-pattern.
An optional Director class encodes reusable named build sequences.

**chapter-08-prototype.md**
Creates new objects by cloning an existing prototype — bypassing expensive re-initialisation.
Python's `copy.deepcopy` is the direct language-level implementation. A Prototype Registry
stores named prototypes for lookup-and-clone by key.

**chapter-09-singleton.md**
Ensures only one instance of a class exists and provides a global access point. In Python,
module-level variables are the idiomatic singleton. The class-based pattern is rarely needed
but important to recognise. Prefer dependency injection over global singleton access in all
new code.

**chapter-10-adapter.md**
Converts an incompatible interface into the one the client expects, by wrapping the Adaptee
in an Adapter that implements the Target Protocol. The surgical tool for integrating
third-party libraries and legacy code without modifying either side.

**chapter-11-bridge.md**
Splits a class into Abstraction and Implementation hierarchies so they can vary independently.
Prevents the M×N subclass explosion when two orthogonal dimensions of variation exist. Bridge
is designed upfront; Adapter is applied after the fact.

**chapter-12-composite.md**
Composes objects into tree structures to represent part-whole hierarchies. Leaf and Composite
nodes share the same Component interface, enabling clients to treat individual objects and
compositions uniformly. The pattern behind file systems, UI trees, and document structures.

**chapter-13-decorator.md**
Attaches responsibilities to objects dynamically by wrapping them in same-interface decorators.
Stacking decorators at runtime avoids a subclass explosion of feature combinations. Python's
`@decorator` syntax is the language-native form of this pattern for functions.

**chapter-14-facade.md**
Provides a simple interface to a complex subsystem. No new business logic — the Facade only
orchestrates and delegates. Every well-designed SDK entry point and service layer is a Facade.
Clients use the Facade for common cases but can still bypass it for full subsystem access.

**chapter-15-flyweight.md**
Reduces memory by sharing intrinsic (immutable) state across thousands of objects. Each
object only stores its unique extrinsic state, passing it to Flyweight methods at call time.
A Flyweight Factory manages the shared pool via a dict cache keyed on intrinsic state.

**chapter-16-proxy.md**
Provides a surrogate for another object, controlling access to it. Three variants: Virtual
(lazy init), Protection (ACL checks), Caching (memoisation). Same structure as Decorator
but different intent — control vs. behaviour addition.

**chapter-17-chain-of-responsibility.md**
Passes a request along a handler chain; each handler decides to process or forward. Decouples
sender from receiver. The middleware pipeline is the most common real-world form. Handlers are
assembled by the client — not by each other.

**chapter-18-command.md**
Encapsulates a request as an object with `execute()` and `undo()`, enabling queuing, logging,
and undoable operations. The Invoker calls commands without knowing their implementation.
Used together with Memento for full undo/redo.

**chapter-19-iterator.md**
Provides a standard traversal interface for collections without exposing internal structure.
Python's `__iter__`/`__next__` protocol IS the Iterator pattern. Generator functions are the
idiomatic lazy iterator implementation.

**chapter-20-mediator.md**
Reduces O(n²) coupling between N components to O(n) by routing all communication through a
central Mediator hub. Components know only the Mediator interface — never each other. The
event bus is a loose variant. Risk: Mediator becomes a God class if coordination logic grows.

**chapter-21-memento.md**
Captures and restores an object's internal state without violating encapsulation. The Originator
creates opaque snapshots (Mementos); the Caretaker stores them. Used with Command for undo/redo.

**chapter-22-observer.md**
One-to-many notification — Publisher notifies all Subscribers when state changes. Foundational
pattern behind every event system. Always provide unsubscribe to prevent memory leaks. Push
model sends data; Pull model sends publisher reference.

**chapter-23-state.md**
Replaces large if/elif chains on a status field with State objects, each encapsulating the
behaviour for one state. State objects initiate transitions. Context delegates all
state-specific calls to the current State.

**chapter-24-strategy.md**
Defines a family of interchangeable algorithms. Context delegates the algorithm to a Strategy
object, enabling runtime swapping. Primary enabler of OCP — new algorithm = new Strategy class,
zero changes to Context. The most frequently used pattern in Python codebases.

**chapter-25-template-method.md**
Defines algorithm skeleton in base class; subclasses fill in specific steps. Abstract steps
are mandatory; hook steps are optional overrides. The Hollywood Principle in action — base
calls subclass hooks. Prefer Strategy over Template Method when flexibility > reuse is needed.

**chapter-26-visitor.md**
Adds operations to a stable object hierarchy without modifying it. Double dispatch via
`accept(visitor)`. Open for new operations (add a Visitor); closed for new element types
(must update all Visitors). Accumulates state across an entire tree in one pass.

---

## Top 15 Key Concepts

1. **Factory Method** — Interface for creating objects; subclasses choose the concrete type (Ch 5)
2. **Abstract Factory** — Creates families of related objects without specifying concrete classes (Ch 6)
3. **Builder** — Step-by-step construction via fluent interface; separates construction from representation (Ch 7)
4. **Observer** — One-to-many notification; Publisher notifies Subscribers on state change (Ch 22)
5. **Strategy** — Family of interchangeable algorithms; swap at runtime (Ch 24)
6. **Decorator** — Dynamically attach responsibilities by wrapping with same-interface objects (Ch 13)
7. **Composite** — Treat individual and composed objects uniformly via a tree structure (Ch 12)
8. **SOLID** — Five principles: SRP, OCP, LSP, ISP, DIP (Ch 4)
9. **Composition over Inheritance** — Prefer HAS-A over IS-A for flexibility (Ch 3)
10. **Adapter** — Convert incompatible interface to expected interface via wrapper (Ch 10)
11. **Command** — Encapsulate request as object with execute/undo (Ch 18)
12. **Proxy** — Surrogate with access control: Virtual, Protection, Caching (Ch 16)
13. **State** — Replace status if/elif chains with State objects that encapsulate per-state behaviour (Ch 23)
14. **Template Method** — Algorithm skeleton in base class; subclasses fill in steps (Ch 25)
15. **Facade** — Simplified interface to a complex subsystem (Ch 14)
