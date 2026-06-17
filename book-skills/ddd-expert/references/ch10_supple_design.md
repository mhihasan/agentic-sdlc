# Ch. 10 — Supple Design

## Chapter Thesis

A model is only as useful as a developer's ability to work with it confidently.
Supple design makes the consequences of using a component predictable from its
interface alone — without requiring developers to read the implementation to know
what will happen.

---

## INTENTION-REVEALING INTERFACES

### Evans' Definition

> "Name classes and operations to describe their effect and purpose, without
> reference to the means by which they do what they promise. This relieves the
> client developer of the need to understand the internals."

### Python Enforcement

Name methods in domain language describing *what happens*, not *how it's done*:

```python
# Wrong — implementation vocabulary leaks through the interface
def subtract_balance_amount(self, cents: int) -> None: ...
def update_order_status_field(self, new_status: str) -> None: ...

# Right — INTENTION-REVEALING INTERFACE (Evans, Ch. 10)
def debit(self, amount: Money) -> None: ...
def confirm(self) -> None: ...
def fulfil(self) -> None: ...
```

Avoid `get_`/`set_` prefixes for meaningful domain operations (appropriate for
simple attribute access, wrong for operations that carry domain meaning).

---

## SIDE-EFFECT-FREE FUNCTIONS

### Evans' Definition

> "Place as much of the logic of the program as possible into functions, operations
> that return results with no observable side effects. Segregate commands (methods
> that change observable state) from queries (methods that return information without
> changing state)."

### Why This Matters

When a method both changes state AND returns a value, a caller cannot use the return
value without triggering the side effect. Complex combinations of such methods become
unpredictable. By keeping queries pure and commands clearly separated, each can be
understood and combined safely.

### Python Enforcement

VALUE OBJECTs should consist entirely of side-effect-free functions:

```python
@dataclass(frozen=True)
class Paint:
    volume_ml: float
    color: Color

    def mix_with(self, other: "Paint") -> "Paint":
        """
        Side-effect-free — returns new Paint, never mutates. (Evans, Ch. 10)
        Caller's instance is unchanged. Safe to combine freely.
        """
        return Paint(
            volume_ml=self.volume_ml + other.volume_ml,
            color=self.color.mix_with(other.color),
        )
```

Commands (methods that change state) should return `None` — the Python convention
that aligns with Evans here. A command that returns a value is a smell.

---

## ASSERTIONS

### Evans' Definition

> "State post-conditions of operations and invariants of classes and AGGREGATES.
> If ASSERTIONS cannot be coded directly in your programming language, write
> automated unit tests for them."

### Python Enforcement

Express invariants explicitly — do not leave them as implicit assumptions:

```python
@dataclass
class Account:
    id: UUID = field(default_factory=uuid4)
    balance_cents: int = 0

    def __post_init__(self) -> None:
        # Invariant declared on construction
        if self.balance_cents < 0:
            raise ValueError("Account balance cannot start negative")

    def debit(self, amount: Money) -> None:
        if amount.amount > self.balance_cents:
            raise InsufficientFundsError(
                f"Cannot debit {amount.amount} from balance {self.balance_cents}"
            )
        self.balance_cents -= amount.amount
        # Post-condition: balance remains non-negative after every debit
        assert self.balance_cents >= 0, "Invariant violated after debit"
```

Unit tests serve as the ASSERTION mechanism Evans recommends where language support
is limited. Test post-conditions explicitly, not just outputs.

---

## CONCEPTUAL CONTOURS

### Evans' Definition

> "Decompose design elements into cohesive units, taking into consideration your
> intuition of the important divisions in the domain. Observe the axes of change
> and stability through successive refactorings and look for the underlying
> CONCEPTUAL CONTOURS that explain these cleavage patterns."

### Practical Meaning

Split classes and modules along lines where the domain itself has natural divisions —
not where code happens to be convenient. The signal that you've found a conceptual
contour: things that always change together and are always used together belong in
the same object. Things that change independently belong in separate objects.

Classic example: `amount` and `currency` always travel together in financial domains →
`Money` VALUE OBJECT is the right contour. Splitting them across two fields on an
entity means they can drift apart.

### Python: Before and After

```python
# WRONG — no conceptual contours respected: amount and currency separate on the entity
# They always change together, always used together — they belong in one object
@dataclass
class Invoice:
    id: UUID = field(default_factory=uuid4)
    amount: int = 0           # always paired with...
    currency: str = "GBP"    # ...this field, but they're separate
    due_date: date = None
    grace_period_days: int = 0   # always used with due_date to compute deadline

    def is_overdue(self, as_of: date) -> bool:
        # Every caller must know how grace_period combines with due_date
        return as_of > self.due_date + timedelta(days=self.grace_period_days)


# RIGHT — contours found: Money groups amount+currency; DueDate groups date+grace
# Each contour encapsulates what changes together (Evans, Ch. 10)
@dataclass(frozen=True)
class Money:
    """Contour: amount and currency always travel together."""
    amount: int
    currency: str

    def add(self, other: "Money") -> "Money":
        if self.currency != other.currency:
            raise ValueError("Currency mismatch")
        return Money(self.amount + other.amount, self.currency)


@dataclass(frozen=True)
class PaymentDeadline:
    """Contour: due_date and grace_period always used together to compute overdue."""
    due_date: date
    grace_period_days: int

    def has_passed(self, as_of: date) -> bool:
        return as_of > self.due_date + timedelta(days=self.grace_period_days)

    @property
    def final_date(self) -> date:
        return self.due_date + timedelta(days=self.grace_period_days)


@dataclass
class Invoice:
    id: UUID = field(default_factory=uuid4)
    amount: Money = None          # conceptual whole
    deadline: PaymentDeadline = None  # conceptual whole

    def is_overdue(self, as_of: date) -> bool:
        # Each contour encapsulates its own logic — caller needs no knowledge of internals
        return self.deadline.has_passed(as_of)
```

The refactored version means: when the business changes how grace periods work,
the change is isolated to `PaymentDeadline`. When currency conversion is added,
it is isolated to `Money`. Neither change touches `Invoice`.

---

## STANDALONE CLASS

Evans introduces STANDALONE CLASS in prose without a formal "Therefore:" block.
The concept is: eliminate all non-essential dependencies from a class until it can
be understood and tested entirely in isolation. Evans: "A STANDALONE CLASS is an
extreme of low coupling."

The most natural candidates are VALUE OBJECTs that encapsulate complex computation
— interest calculations, color mixing, date range arithmetic. Every dependency
removed from such a class reduces the cognitive load of understanding it.

```python
# STANDALONE CLASS — no imports from other domain objects (Evans, Ch. 10)
@dataclass(frozen=True)
class PigmentColor:
    """
    Can be studied and tested alone — zero domain dependencies.
    All operations are side-effect-free (return new instances).
    """
    red: int    # 0–255
    green: int
    blue: int

    def mix_with(self, other: "PigmentColor") -> "PigmentColor":
        return PigmentColor(
            red=(self.red + other.red) // 2,
            green=(self.green + other.green) // 2,
            blue=(self.blue + other.blue) // 2,
        )
```

Evans' observation: when this class is extracted and freed of entanglement, "every
such self-contained class significantly eases the burden of understanding a MODULE."

---

## CLOSURE OF OPERATIONS

### Evans' Definition

> "Where it fits, define an operation whose return type is the same as the type of
> its argument(s). If the implementer has state that is used in the computation, then
> the implementer is effectively an argument of the operation, so the argument(s) and
> return value should be of the same type as the implementer."

### Python Enforcement

The clearest example in DDD is arithmetic on VALUE OBJECTs:

```python
@dataclass(frozen=True)
class Money:
    amount: int
    currency: str

    def add(self, other: "Money") -> "Money":   # Money + Money = Money
        if self.currency != other.currency:
            raise ValueError("Currency mismatch")
        return Money(self.amount + other.amount, self.currency)

    def multiply(self, factor: int) -> "Money":  # Money * int = Money
        return Money(self.amount * factor, self.currency)
```

The closed set of operations makes combining values intuitive — callers never have
to reason about type conversion or intermediate representations.

### What This Chapter Does Not Cover

Evans does not address functional programming patterns, monads, or any specific
Python feature for enforcing these properties beyond the design principles described.
The patterns are design heuristics, not language features.
