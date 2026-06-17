# Chapter 1: Clean Code

## Core Thesis
Bad code is the primary cause of slowing teams down over time. The only way to go fast is to keep code clean. "LeBlanc's Law: Later equals never."

## What Is Clean Code? (Expert Definitions)

| Expert | Definition |
|--------|-----------|
| Bjarne Stroustrup | Elegant and efficient; logic is straightforward; minimal dependencies; does one thing well |
| Grady Booch | Simple and direct; reads like well-written prose; never obscures designer's intent |
| "Big" Dave Thomas | Can be read and enhanced by other developers; has unit tests; minimal API |
| Michael Feathers | Code that looks like it was written by someone who **cares** |
| Ron Jeffries | No duplication; one thing; expressiveness; tiny abstractions |
| Ward Cunningham | Code is clean when each routine turns out to be pretty much what you expected |

## Key Concepts

### The Total Cost of Owning a Mess
- Teams start fast but slow asymptotically toward zero productivity
- Every change to messy code breaks two or three other parts
- Adding more developers to a messy codebase accelerates the mess
- The Grand Redesign trap: new system races with old; often takes 10 years; becomes equally messy

### The Primal Conundrum
You will not make the deadline by making a mess. The mess slows you immediately. The **only** way to go fast is to keep code clean at all times.

### Code-Sense
The ability to recognize a mess AND to see strategies for transforming it. It is a learned discipline — not purely innate.

### The Boy Scout Rule
> "Leave the campground cleaner than you found it."

Every time you touch code, make it slightly better. No large refactors required — just continuous, incremental improvement.

## Python Examples

### Messy Code (violates every principle)
```python
# BAD: No intention, magic numbers, no structure
def p(d):
    r = []
    for x in d:
        if x[0] == 4:
            r.append(x)
    return r
```

### Clean Code (what we're aiming for)
```python
# GOOD: Intention-revealing, self-documenting
FLAGGED_STATUS = 4
STATUS_INDEX = 0

def get_flagged_cells(game_board: list[list[int]]) -> list[list[int]]:
    """Return all cells that have been flagged by the player."""
    return [cell for cell in game_board if cell[STATUS_INDEX] == FLAGGED_STATUS]
```

### Even Better: With a Domain Object
```python
from dataclasses import dataclass

@dataclass
class Cell:
    status: int
    x: int
    y: int

    def is_flagged(self) -> bool:
        return self.status == FLAGGED_STATUS

def get_flagged_cells(game_board: list[Cell]) -> list[Cell]:
    return [cell for cell in game_board if cell.is_flagged()]
```

### The Boy Scout Rule in Practice
```python
# Before touching this function, you find:
def calc(x, y, t):
    return x * y * (1 + t/100)

# After your touch (even if your change is elsewhere), leave it better:
def calculate_price_with_tax(base_price: float, quantity: int, tax_rate_percent: float) -> float:
    """Calculate total price including tax."""
    return base_price * quantity * (1 + tax_rate_percent / 100)
```

## Heuristics from This Chapter

1. **C1** — Intention-revealing naming is the foundation of all clean code
2. **C2** — Code that requires a comment to explain what it does is not yet clean
3. **C3** — Cleanliness is a professional responsibility, not optional
4. **C4** — Technical debt accrues interest; pay it down continuously

## Common Anti-Patterns to Avoid

| Anti-Pattern | Consequence | Fix |
|---|---|---|
| "I'll clean it up later" | Never happens (LeBlanc's Law) | Clean it now |
| Adding staff to fix mess | Accelerates the mess | Refactor before scaling |
| Grand redesign without boy-scout discipline | New codebase becomes equally messy | Incremental improvement |
| Blaming managers/requirements | Removes agency | Own the code quality |
