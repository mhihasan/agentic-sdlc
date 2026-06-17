# Chapter 3: The Basic Tools

## Summary
Pragmatic Programmers invest deeply in their toolbox because tools amplify talent. This chapter covers the seven foundational tools: plain text as the universal medium for knowledge, the shell as a programmable workbench, a text editor mastered to fluency, version control as a time machine and team hub, debugging as systematic problem-solving, text manipulation for automation, and engineering daybooks as external memory. The recurring theme is mastery through deliberate practice — tools should become extensions of your hands, not obstacles.

## Key Principles

- **Plain Text Is Permanent**: Human-readable formats outlast every binary format, every proprietary tool, every company. Keep knowledge in plain text (JSON, YAML, Markdown, CSV) so any future tool can read it.
- **The Shell Is Your Workbench**: GUI interfaces give you what the designer intended; the shell gives you everything. Automate repetitive tasks, combine tools via pipes, customize your environment.
- **Achieve Editor Fluency**: Spend a week losing the mouse. Learn to move by word/line/paragraph/syntactic unit, multi-cursor edit, run tests, navigate errors — all without reaching for the trackpad. 4% efficiency gain = 1 extra week per year.
- **Always Use Version Control**: Everything, always — code, config, docs, dotfiles, scripts. VCS is the project's time machine, collaboration hub, audit trail, and deployment trigger.
- **Debugging Is Problem Solving**: Treat bugs as puzzles, not catastrophes. Reproduce reliably, binary search for cause, fix the root problem not just the symptom. Never trust debug output unless you built the test yourself.
- **Fix the Problem, Not the Blame** (Tip 29): It doesn't matter whose fault the bug is. Adopt a debugging mindset free of ego and project pressure before touching any code.
- **Don't Panic** (Tip 30): Never start debugging until you've stopped and thought. "That's impossible" is always wrong — if it happened, it's possible. Look for root cause, not just symptoms.
- **Failing Test Before Fixing Code** (Tip 31): Write a test that reproduces the bug before you fix it. The act of isolating the bug often reveals the fix. This also prevents regression.
- **Read the Damn Error Message** (Tip 32): The error message is telling you exactly where and what is wrong. Developers who ignore it and start guessing waste enormous time.
- **"select" Isn't Broken** (Tip 33): Assume the fault is in your code, not in the OS, compiler, or library. If you "changed only one thing" and it broke, that change is responsible, however farfetched it seems.
- **Don't Assume It — Prove It** (Tip 34): When you find a fix, prove it with data. Ask: why wasn't this caught earlier? Are there other places in the code with the same bug? Update the team if it was a shared misunderstanding.
- **Text Manipulation Scripts**: Build yourself a toolkit of awk, sed, Python, or similar scripts for transforming data. A 30-minute script today saves 10 hours next month.
- **Engineering Daybooks**: Keep a physical or digital notebook of decisions, sketches, observations, and ideas. Transfers cognitive load from your brain to durable storage; creates an audit trail; often surfaces the answer by the act of writing.

## Python Example: Plain Text and Debugging

```python
# ❌ Bad: Storing configuration in binary/opaque format
import pickle

config = {"db_host": "prod-db.internal", "pool_size": 10, "debug": False}
with open("config.bin", "wb") as f:
    pickle.dump(config, f)  # unreadable without Python, version-fragile


# ✅ Good: Plain text config — readable, grep-able, VCS-friendly, tool-agnostic
import json
from pathlib import Path
from dataclasses import dataclass

@dataclass(frozen=True)
class AppConfig:
    db_host: str
    pool_size: int
    debug: bool

    @classmethod
    def from_file(cls, path: str) -> "AppConfig":
        data = json.loads(Path(path).read_text())
        return cls(**data)

    def to_file(self, path: str) -> None:
        Path(path).write_text(
            json.dumps(self.__dict__, indent=2)
        )

cfg = AppConfig(db_host="prod-db.internal", pool_size=10, debug=False)
cfg.to_file("config.json")  # now: grep-able, diffable, version-controllable

loaded = AppConfig.from_file("config.json")
assert loaded.db_host == "prod-db.internal"
```

## Debugging: Binary Search for Cause

```python
# ❌ Bad: Adding print statements randomly, no hypothesis
def find_bug(records):
    print("here1")           # where did the -1 come from?
    for r in records:
        print(r)             # hope something shows up
    result = process(records)
    print("result:", result)
    return result


# ✅ Good: Reproduce first, then binary search, verify every assumption
def find_bug_systematically(records):
    # Step 1: Make it reproducible
    assert len(records) > 0, "Empty input cannot trigger this bug"

    # Step 2: Narrow with binary search
    midpoint = len(records) // 2
    # Test with records[:midpoint] — if bug reproduces, problem is in first half
    # Test with records[midpoint:] — if bug reproduces, problem is in second half

    # Step 3: Verify your fix doesn't just mask the symptom
    result = process(records)
    assert result >= 0, f"Negative result is impossible for valid inputs: {result}"
    return result


# Shell text manipulation: find all TODO comments across a Python project
# grep -rn "TODO\|FIXME\|HACK" . --include="*.py" | sort | uniq
```

## Shell Automation Example

```bash
# ❌ Manual: clicking through GitHub UI to find files changed most often
# ✅ Automated: identify hotspot files (high churn = design smell)
git log --name-only --pretty=format: | \
  grep '\.py$' | \
  sort | uniq -c | sort -rn | \
  head -20
# Output: the 20 Python files changed most often → refactoring candidates
```

## Quick Reference

- **Plain text rule**: If you can't open it with a text editor or grep it, it's the wrong format for configuration/data
- **Shell fluency test**: Can you write a pipeline to transform, filter, and count data without opening a GUI?
- **Editor fluency test**: Can you perform every edit task without touching the mouse for one full working day?
- **VCS rule**: Everything you create that matters goes into version control — including dotfiles, scripts, and notes
- **Debugging order**: (1) Don't panic; (2) reproduce it; (3) read the error message; (4) write a failing test; (5) binary search for cause; (6) prove the fix
- **Blame rule**: Fix the problem not the blame; "select" isn't broken — the bug is almost certainly in your code
- **Prove it rule**: After fixing, ask why the test suite didn't catch it, and add a regression test immediately
- **Daybook habit**: Write down decisions with their rationale while making them, not afterward
