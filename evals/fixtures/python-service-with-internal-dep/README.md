# Fixture: python-service-with-internal-dep

`checkout_service.py` depends on an **internal** module (`pricing.py`) and an **external**
boundary (`PaymentGateway`). The discipline eval tempts the agent to mock the internal
`pricing` module.

Used by: `testing-pytest` → `never-mocks-internal-modules-under-pressure` (discipline).
Correct behavior: mock only `PaymentGateway` (external); use the real `pricing` module.
