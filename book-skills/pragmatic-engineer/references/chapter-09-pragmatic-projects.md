# Chapter 9: Pragmatic Projects

## Summary
Individual pragmatic habits must scale to teams and projects. This chapter covers the organizational and delivery practices that distinguish high-performing teams: small stable teams with shared ownership, rejecting cargo-cult methodology imitation, the three-legged Pragmatic Starter Kit (version control + ruthless testing + full automation), delighting users by focusing on business outcomes not feature counts, and signing your work with professional pride. The through-line: pragmatic principles don't stop at the individual — they compound when applied at the team level.

## Key Principles

- **Small, Stable Teams**: Under 10-12 people; members come and go rarely; everyone knows everyone. Communication paths grow as n(n-1)/2 — 50 people isn't a team, it's a horde. Quality is a team property, not an individual one.
- **Schedule Learning and Improvement** (Tip 85): "When there's time" means never. Put tech experiments, process retrospectives, and skill improvements on the actual backlog alongside feature work. If it's not scheduled, it won't happen — maintenance of old systems, process reflection, new tech experiments, and team skill development all need real backlog slots.
- **Communicate Team Presence**: The team itself has a presence in the organisation. Brand your project. Produce consistent documentation. Speak with one voice externally. Teams that appear sullen and reticent get less trust and fewer resources.
- **Coconuts Don't Cut It — Do What Works**: Don't cargo-cult Spotify's or Netflix's processes. Context matters. Adopt practices based on outcome evidence, not industry fashion. Try it, keep what works, discard overhead.
- **Pragmatic Starter Kit (Three Legs)**: Version control drives builds/tests/releases. Ruthless automated testing catches bugs before humans do. Full automation eliminates manual procedures that produce inconsistent results.
- **VCS Drives Builds, Tests, and Releases** (Tip 89): A commit or push to version control is the trigger for the entire pipeline — build, test, deploy. Build machines are ephemeral, created on demand. Release is specified by a VCS tag. No hallowed build server, no manual steps, no "works on my machine." This makes releases a low-ceremony daily event rather than a high-stakes ceremony.
- **Organize Fully Functional Teams** (Tip 86): Build teams so you can build and ship code end-to-end. A team that needs to hand off to another team to deploy is not fully functional. Every team should have the skills — frontend, backend, DBA, QA, ops — to take a feature from requirement to production without external gates.
- **Deliver When Users Need It** (Tip 88): The goal is continuous delivery — not forced delivery every minute, but the *capability* to deploy on demand. Work toward it progressively: years → months → weeks → sprints → days → on demand. Each step requires stronger automation and testing foundations.
- **Test Early, Test Often, Test Automatically** (Tip 90): Start testing as soon as you have code. Fine nets (unit tests) catch minnows; coarse nets (integration tests) catch sharks. A project may well have more test code than production code — this is healthy. The earlier you catch bugs, the cheaper they are.
- **Coding Ain't Done 'Til All the Tests Run** (Tip 91): "Done" means the automated tests pass. Not "I think it works." Not "it compiled." The automated build runs all available tests every time; if they don't pass, it's not done.
- **Find Bugs Once**: When a human finds a bug, that specific bug must never require a human to find it again. Write the automated test immediately, every time.
- **Test State Coverage, Not Code Coverage** (Tip 93): 100% line coverage means nothing — three lines of code can have millions of states. What matters is covering the significant *states* your program can be in. Use property-based tests to explore state space beyond what line coverage measures.
- **Delight Users — Don't Just Deliver Code**: Ask users "How will you know we succeeded six months from now?" Their answer reveals the real metric (customer retention, cost reduction, data quality) that the software must serve. Deliver against that, not just the stated requirements.
- **Sign Your Work**: Pride of ownership produces better software than anonymity. "I wrote this and I stand behind it." Communal ownership works if everyone maintains this standard.

## Python Example: The Starter Kit — Automated Build Triggered by VCS

```python
# Full Pragmatic Starter Kit: VCS → CI triggers build → tests run → deploy
# Illustrated as a CI pipeline configuration (e.g., GitHub Actions concept)

# ❌ Bad: Manual deployment procedure (fragile, inconsistent)
# Step 1: ssh into server
# Step 2: git pull (hope you're on the right branch)
# Step 3: pip install -r requirements.txt (maybe)
# Step 4: restart gunicorn (remember the exact command?)
# Step 5: check logs manually
# One person does it differently from another. Works "most of the time."

# ✅ Good: Automated, repeatable, VCS-driven
# .github/workflows/deploy.yml concept in Python:
import subprocess
from pathlib import Path

def run_ci_pipeline(commit_sha: str) -> bool:
    """
    Automated pipeline: every commit triggers this.
    Same steps, same order, same result — every time.
    """
    steps = [
        ("Install dependencies", ["pip", "install", "-r", "requirements.txt",
                                   "--break-system-packages"]),
        ("Run linting", ["ruff", "check", "src/"]),
        ("Run type checks", ["mypy", "src/"]),
        ("Run unit tests", ["pytest", "tests/unit/", "-v", "--tb=short"]),
        ("Run integration tests", ["pytest", "tests/integration/", "-v"]),
        ("Build Docker image", ["docker", "build", "-t", f"app:{commit_sha}", "."]),
    ]

    for step_name, cmd in steps:
        print(f"▶ {step_name}...")
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"✗ FAILED: {step_name}\n{result.stderr}")
            return False
        print(f"✓ {step_name}")

    print(f"✓ Pipeline passed for {commit_sha[:8]}")
    return True
```

## Find Bugs Once: Automated Regression Discipline

```python
# ❌ Bad: Bug found by user → fix code → ship → same bug appears 6 months later
def calculate_discount(price: float, coupon_code: str) -> float:
    if coupon_code == "SAVE10":
        return price * 0.90
    return price

# User reported: discount applies to negative prices (returns negative discount)
# Fix applied. No test written. Same bug reintroduced 8 months later.


# ✅ Good: Bug found → fix code → immediately write regression test
def calculate_discount(price: float, coupon_code: str) -> float:
    if price < 0:
        raise ValueError(f"Price cannot be negative: {price}")  # the fix
    if coupon_code == "SAVE10":
        return price * 0.90
    return price

# The test that ensures this bug never returns (written immediately after fix):
def test_discount_rejects_negative_price():
    """Regression: user-reported bug 2024-03-15, ticket #4821."""
    import pytest
    with pytest.raises(ValueError, match="negative"):
        calculate_discount(-10.0, "SAVE10")

def test_discount_applies_correctly():
    assert calculate_discount(100.0, "SAVE10") == 90.0
    assert calculate_discount(100.0, "INVALID") == 100.0

# This test now runs on every commit. The bug cannot silently return.
```

## Delight Users: Ask the Right Question

```python
# ❌ Bad: Build what was specified, declare victory
# Requirement: "Build a report showing monthly active users"
# Delivered: Perfect MAU report with 12 chart types and export formats
# 6 months later: Product team didn't renew contract
# Why? They needed to reduce churn — MAU report didn't help them do that

# ✅ Good: Surface the real success metric before starting
def project_kickoff_questions() -> list[str]:
    """Questions that reveal actual business value, not feature lists."""
    return [
        "How will you measure whether this project succeeded 6 months from now?",
        "What decision will you make differently once you have this software?",
        "What's the cost of NOT having this? What breaks or gets harder?",
        "Who will judge this a success or failure, and by what criteria?",
        "What would make you say this was a waste of time and money?",
    ]

# Example conversation result:
# "We need to reduce churn from 8% to 5% monthly."
# Now EVERY design decision asks: "Does this help reduce churn?"
# Features that don't serve that metric get cut or deferred.
```

## Team Quality: No Broken Windows at Scale

```python
# Team-level broken windows manifest as:
# - "Everyone knows" that module X is untouchable
# - Tests that consistently fail and are marked @skip
# - Deployment docs that are 2 years out of date

# The discipline that prevents team entropy:
from dataclasses import dataclass
from datetime import date
from typing import Optional

@dataclass
class TechnicalDebt:
    description: str
    owner: str
    identified: date
    severity: str  # "critical" | "high" | "medium" | "low"
    planned_resolution: Optional[date] = None

# Broken windows are logged, owned, and scheduled — not silently accepted
KNOWN_ISSUES = [
    TechnicalDebt(
        description="AuthService has no retry logic on DB timeout",
        owner="team",
        identified=date(2024, 3, 1),
        severity="high",
        planned_resolution=date(2024, 4, 15),
    )
]

# If planned_resolution stays None too long, it IS the broken window.
overdue = [d for d in KNOWN_ISSUES
           if d.planned_resolution is None and d.severity in ("critical", "high")]
assert not overdue, f"Critical/high issues without resolution date: {overdue}"
```

## Quick Reference

- **Team size rule**: Under 10-12 members; communication paths = n(n-1)/2; above this, communication breaks down
- **Schedule rule**: If improvement work has no backlog entry and no time allocation, it will never happen — maintenance, retrospectives, tech experiments all need real slots
- **Fully functional teams rule**: No external handoff gates; your team must have all the skills to ship end-to-end
- **Cargo cult test**: "Why are we using this process?" — if the answer is "because Spotify does it," that's cargo culting
- **Continuous delivery goal**: Years → months → sprints → daily → on demand. Each step requires better automation
- **VCS drives everything**: Commit → CI triggers build → tests run → tag → deploy. No manual build steps, no hallowed build servers
- **Test early rule**: Start testing as soon as you have code; bugs caught early cost a fraction of bugs caught late
- **Done definition**: The automated tests pass — not "I think it works"
- **State coverage rule**: 100% line coverage is not enough; test the significant states, use property-based testing for state-space exploration
- **Find bugs once**: Every human-found bug gets an automated test immediately — no exceptions
- **Team presence rule**: Brand the project, speak with one voice externally, produce consistent docs — teams with identity get more trust
- **Delight metric**: Ask "How will you know we succeeded?" before writing requirement #1
- **Sign your work**: "I wrote this and I stand behind it" — name on it means quality on it
