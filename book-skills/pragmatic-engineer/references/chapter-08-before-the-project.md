# Chapter 8: Before the Project

## Summary
Before writing a single line of production code, two traps can derail a project: misunderstanding what users actually want, and framing problems so narrowly that solutions are missed. This chapter covers four topics: The Requirements Pit (requirements are discovered, not gathered); Solving Impossible Puzzles (find the real constraints before abandoning a problem); Working Together (pair and mob programming as problem-solving, not just typing); and The Essence of Agility (agile is a feedback loop, not a methodology). The unifying principle: build a short, tight feedback cycle between code and the people who need it.

## Key Principles

- **No One Knows Exactly What They Want**: The client's initial statement is an invitation to explore, not a specification to implement. Developers who take requirements literally and implement them without questioning produce exactly what was asked for and nothing like what was needed.
- **Programmers Help People Understand What They Want** (Tip 76): This is our most valuable attribute. Clients come with a need and an amateur implementation guess dressed as a requirement. Our job is to surface the real need through dialogue, prototypes, and feedback — not to implement the stated requirement uncritically.
- **Requirements Are a Feedback Loop**: Your job is to generate working artifacts (mockups, prototypes, tracer bullets) that trigger refined thinking in the client. Requirements emerge from the interaction, not from an upfront document.
- **Work with a User to Think Like a User** (Tip 78): Sit with users doing their actual job for a day or a week. You'll discover how the system is *really* used — in ways that no requirements document captures. This also builds trust and surfaces the real pain points.
- **Policy Is Metadata**: If a requirement embeds business policy ("only supervisors can view records"), extract the policy into configuration. Implement the mechanism; parameterize the policy.
- **Use a Project Glossary**: One authoritative definition of every domain term prevents two people calling the same thing by different names — which is one of the most common sources of bugs and rework.
- **Find the Box — Don't Think Outside It**: "Impossible" problems usually have more degrees of freedom than they appear. The constraint you're accepting may not be a real constraint. Enumerate all paths, challenge every assumed restriction.
- **Don't Go into the Code Alone**: Pair and mob programming multiply problem-solving bandwidth. One person types; others think at the higher level simultaneously. Prevents ego-driven shortcuts, improves design, accelerates debugging.
- **Agile Is How You Do Things, Not What You Do**: Agility is a feedback loop: (1) work out where you are, (2) take the smallest meaningful step toward where you want to be, (3) evaluate and fix what you broke, (4) repeat. No fixed methodology implements this for you.

## Python Example: Policy as Metadata

```python
# ❌ Bad: Business policy hardcoded in application logic
class EmployeeRecord:
    def can_view(self, viewer_role: str) -> bool:
        # Hardcoded policy — changing who can view requires code change + redeploy
        return viewer_role in ("supervisor", "personnel_dept", "hr_admin")

    def view(self, viewer_role: str) -> dict:
        if not self.can_view(viewer_role):
            raise PermissionError(f"Role '{viewer_role}' cannot view employee records")
        return self._data


# ✅ Good: Mechanism in code, policy in configuration (metadata)
from dataclasses import dataclass, field
from typing import FrozenSet

@dataclass(frozen=True)
class AccessPolicy:
    """Policy is data — change it without touching application code."""
    allowed_roles: FrozenSet[str]

    def permits(self, role: str) -> bool:
        return role in self.allowed_roles

    @classmethod
    def from_config(cls, config: dict, resource: str) -> "AccessPolicy":
        roles = frozenset(config["access_control"][resource]["allowed_roles"])
        return cls(allowed_roles=roles)

# Config (YAML/JSON/env) — policy lives here, not in code:
# access_control:
#   employee_record:
#     allowed_roles: [supervisor, personnel_dept]

class EmployeeRecord:
    def __init__(self, data: dict, access_policy: AccessPolicy):
        self._data = data
        self._policy = access_policy   # injected — not hardcoded

    def view(self, viewer_role: str) -> dict:
        if not self._policy.permits(viewer_role):
            raise PermissionError(
                f"Role '{viewer_role}' not authorized. "
                f"Authorized roles: {self._policy.allowed_roles}"
            )
        return self._data

# Changing policy = change config file, no code change required
policy = AccessPolicy(frozenset({"supervisor", "personnel_dept"}))
record = EmployeeRecord({"name": "Alice", "salary": 95000}, policy)

try:
    record.view("contractor")
except PermissionError as e:
    assert "contractor" in str(e)

record.view("supervisor")  # succeeds
```

## Agility: The Minimal Feedback Loop

```python
# The agile loop applied at every scale — from variable naming to architecture

# MICRO LEVEL: variable naming feedback loop (from the book's example)
# Step 1: where are you?
user = account_owner(account_id)  # user — feels wrong
# Step 2: smallest meaningful step
owner = account_owner(account_id)  # owner — still redundant?
# Step 3: evaluate
# "What am I actually doing with this?" → sending an email
email = email_of_account_owner(account_id)  # now the intent is clear
# Reduced coupling: no longer fetching a full User object just to send email

# SPRINT LEVEL: feedback loop as incremental delivery
from dataclasses import dataclass
from typing import Callable, Any

@dataclass
class FeedbackLoop:
    """Model the pragmatic agile loop explicitly."""
    name: str

    def iterate(
        self,
        current_state: Any,
        step: Callable[[Any], Any],
        evaluate: Callable[[Any], bool],
        max_iterations: int = 10,
    ) -> Any:
        """
        Iterate: assess → step → evaluate → repeat.
        Stops when evaluate returns True or max_iterations exceeded.
        """
        for i in range(max_iterations):
            next_state = step(current_state)
            if evaluate(next_state):
                print(f"{self.name}: converged after {i+1} iterations")
                return next_state
            current_state = next_state
        raise RuntimeError(f"{self.name}: did not converge in {max_iterations} steps")
```

## Requirements as Feedback: User Stories vs. Spec Documents

```python
# ❌ Bad: 200-page requirements document that clients sign but don't read
# "The system shall provide a user interface allowing authorized personnel to
#  submit, modify, delete, and query shipping-related transactional records
#  with response times not exceeding 500 milliseconds under peak load..."

# ✅ Good: Index-card user story — short enough to generate questions
USER_STORY = """
As a warehouse supervisor,
I want to see all orders awaiting fulfillment,
So that I can prioritize picking for today's shipments.

Acceptance criteria:
- Shows orders sorted by ship-by date (earliest first)
- Filters to current warehouse only
- Updates without page refresh

Open questions (to resolve with client):
- What does "awaiting fulfillment" mean exactly? (not-picked? not-packed?)
- Is "today's shipments" based on promised delivery date or carrier cutoff?
"""
# Short stories generate questions. Questions generate understanding.
# Understanding produces better software than 200 pages ever will.
```

## Quick Reference

- **Requirements rule**: Initial statement = invitation to explore; never implement it literally without questioning
- **Tip 76 rule**: Your most valuable role is helping clients understand what they actually want — not implementing what they said
- **Work with users rule**: Sit with users for a day; you'll learn more in one day than from a month of requirements documents
- **Policy vs. mechanism**: "Only role X can do Y" is policy → put in config; the access control mechanism goes in code
- **Glossary rule**: Create it at project start; update it continuously; one definition per term, shared by all
- **Impossible puzzle rule**: Enumerate all paths including "obviously stupid" ones; challenge every assumed constraint
- **Pairing rule**: Typing person handles syntax/details; non-typing person handles higher-level design concerns
- **Agile loop**: Where are you? → smallest step → evaluate → fix → repeat (at every scale, recursively)
- **Agile anti-pattern**: Cargo-culting a methodology's ceremonies without its underlying feedback discipline
