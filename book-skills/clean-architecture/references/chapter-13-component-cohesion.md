# Chapter 13: Component Cohesion

## Summary
Three principles govern which classes belong in the same component. They form a tension triangle — no single principle is universally correct; the right balance shifts with project maturity.

| Principle | Bias | Rule |
|---|---|---|
| **REP** — Reuse/Release Equivalence | Reusability | Release granule = reuse granule. Group what is released together. |
| **CCP** — Common Closure | Maintainability | Things that change together, live together. Component-level SRP. |
| **CRP** — Common Reuse | Deployment efficiency | Don't force consumers to depend on things they don't use. Component-level ISP. |

## Key Principles
- **REP**: Don't half-publish a component. If only 3 of 10 classes are useful to consumers, split it.
- **CCP**: A single business change should require touching exactly one component. Minimises the number of components that must be versioned and redeployed.
- **CRP**: Every class in a component is a dependency its consumers take on. Unused classes still cause rebuilds when they change.
- **Tension**: REP + CCP push toward larger components (group by relatedness). CRP pushes toward smaller components (split unnecessary coupling).

## Python Example

```python
# ---- CCP: Group by reason to change, not by technical type ----

# ❌ Bad: Package-by-layer — one business change touches 3 packages
# models/order.py         ← change here
# services/order_svc.py   ← and here
# repos/order_repo.py     ← and here
# All three packages must be versioned and released for one tax rule change.

# ✅ Good: Package-by-domain (CCP) — one business change touches 1 package
# order_management/
#   _order.py         ← entity
#   _use_cases.py     ← business logic
#   _repository.py    ← data access interface (+ impl)
# Tax rule change: touch order_management only. One release.


# ---- CRP: Don't force consumers to depend on unused classes ----
# Scenario: a Lambda reads from SQS and needs only JSON formatting.

# ❌ Bad: Fat utils package — Lambda pulls in reportlab (10MB PDF library)
# utils/
#   __init__.py   ← imports JsonFormatter AND PdfGenerator AND ExcelExporter

# ✅ Good: Narrow packages — consumers take only what they need
# json_utils/          ← 2KB — used by API handlers and Lambdas
# pdf_utils/           ← 8MB — used only by the report generator service
# excel_utils/         ← 5MB — used only by the export service

# Lambda deployment: pip install json_utils   # 2KB, not 13MB
```

```python
# ---- Tension triangle: choosing the right balance ----
from dataclasses import dataclass
from enum import Enum

class ProjectPhase(Enum):
    EARLY   = "New team, everything changes, release cadence weekly"
    MATURE  = "Stable core, multiple downstream consumers, SLA-bound"

def recommended_bias(phase: ProjectPhase) -> str:
    if phase == ProjectPhase.EARLY:
        # Changes are frequent — keep related things together to minimise
        # cross-component friction. Large components are acceptable.
        return "Bias toward CCP: group by domain, accept large components."
    else:
        # Downstream consumers multiply — clean releases and narrow interfaces matter.
        # Split to avoid forcing unused dependencies on consumers.
        return "Bias toward REP + CRP: narrow public APIs, split by usage pattern."

# Assertion to make it concrete:
assert "CCP" in recommended_bias(ProjectPhase.EARLY)
assert "REP" in recommended_bias(ProjectPhase.MATURE)
```

```python
# ---- REP: The granule of reuse is the granule of release ----
# A component that bundles HTTP client + retry logic + circuit breaker is fine
# IF consumers always need all three together.
# If consumers sometimes need just retry logic, split it:

# ❌ Bad: bundled into one package
# pip install infra_utils   # gives you HTTP client, retry, circuit breaker, metrics, logging

# ✅ Good: split by reuse granule
# pip install retry_utils          # 3KB — just retry with backoff
# pip install circuit_breaker      # 8KB — just circuit breaker
# pip install http_client          # depends on retry_utils (same release group)

# Consumer A (simple Lambda): pip install retry_utils       # no circuit breaker overhead
# Consumer B (high-traffic API): pip install http_client circuit_breaker
```

## Quick Reference
- REP: release granule = reuse granule — don't half-publish a component
- CCP: things that change together, belong together (component-level SRP)
- CRP: don't force dependencies on things not used (component-level ISP)
- Early projects → bias CCP (large, domain-grouped components)
- Mature libraries → bias REP + CRP (narrow, split-by-usage components)
