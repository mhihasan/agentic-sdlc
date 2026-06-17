# Chapter 7: SRP — The Single Responsibility Principle

## Summary
SRP is widely misquoted as "a module should do one thing." Martin's precise definition: **a module should have exactly one reason to change**, meaning it is responsible to exactly one actor (business stakeholder). When multiple actors own a module, a change requested by one actor unintentionally breaks behaviour for another. The symptom is accidental coupling: seemingly unrelated features breaking each other.

## Key Principles
- **One actor, not one function**: Cohesion is defined by *who cares about it*, not how many functions it has.
- **Accidental duplication**: Two modules that look similar but serve different actors should NOT be merged — they will diverge for different reasons.
- **Separation by actor**: Split modules so each actor owns exactly one module.

## Anti-Patterns
- `Employee` class with `calculate_pay()` (Finance), `report_hours()` (HR), `save()` (DBA) — three actors, one class
- Sharing a `format_hours()` helper between Finance and HR — they will diverge

## Python Example

```python
# ❌ Bad: Three actors coupled into one class
class Employee:
    name: str
    hours: float
    rate: float

    def calculate_pay(self) -> float:       # Finance owns this
        return self.hours * self.rate

    def report_hours(self) -> str:          # HR owns this
        return f"{self.name}: {self.hours}h"

    def save(self) -> None:                 # DBA owns this
        db.execute("UPDATE employees ...")

# Finance asks: "change how overtime is calculated"
# Developer edits calculate_pay() and accidentally touches the hours attribute
# in a way that breaks report_hours(). HR's report is now wrong.
```

```python
# ✅ Good: Split by actor — pure data shared, behaviour separated
from dataclasses import dataclass

@dataclass
class EmployeeData:              # shared data — no behaviour
    name: str
    hours: float
    rate: float

# Finance actor — only Finance can cause this to change
def calculate_pay(emp: EmployeeData) -> float:
    return emp.hours * emp.rate

# HR actor — only HR can cause this to change
def report_hours(emp: EmployeeData) -> str:
    return f"{emp.name}: {emp.hours}h"

# DBA actor — only DBA schema changes affect this
def save_employee(emp: EmployeeData) -> None:
    db.execute("UPDATE employees SET name=?, hours=?, rate=?",
               (emp.name, emp.hours, emp.rate))

# Functions are the natural unit here — not classes.
# Each function has exactly one reason to change: its actor's requirements.
```

```python
# When behaviour is more complex, a class per actor still works:
class PayCalculator:             # Finance actor
    def calculate(self, emp: EmployeeData) -> float:
        # Complex overtime, tax, and bonus logic owned by Finance
        overtime = max(0, emp.hours - 40) * emp.rate * 1.5
        regular = min(emp.hours, 40) * emp.rate
        return regular + overtime

class HourReporter:              # HR actor — uses different hours definition
    def report(self, emp: EmployeeData) -> str:
        # HR tracks hours differently — they include meeting time
        return f"{emp.name}: {emp.hours}h (including 2h meetings)"
```

## Quick Reference
- SRP = one reason to change = one actor (business stakeholder)
- Smell: a class appears in two different teams' change requests
- Python fix: split by actor — use module-level functions or separate classes
- Share only pure data objects (`@dataclass`) across actors
