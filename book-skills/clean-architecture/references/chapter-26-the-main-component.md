# Chapter 26: The Main Component


## Summary
`Main` is the dirtiest, most concrete, most volatile component in the system. It creates everything, wires all dependencies, and starts execution. Main is a **plugin** to the application — different Main modules can configure the system for production, testing, development, or different environments without touching any business logic. Main is the only component that is allowed to import concrete implementations.

## Key Principles
- **Main = dependency injector and wirer**: It knows about every concrete class so nothing else has to.
- **Main is a plugin**: Swap Main to swap the entire configuration (DB, email provider, feature flags).
- **Main is not tested**: It's too concrete and too volatile. It's exercised by integration/end-to-end tests only.

## Python Example

```python
# Main: the only file allowed to import concrete classes
# production_main.py

from order_management.use_cases import PlaceOrder, CancelOrder
from order_management.use_cases import PlaceOrderController
from infrastructure.postgres_repos import PostgresOrderRepository
from infrastructure.ses_email import SesEmailSender
from infrastructure.stripe_billing import StripeBillingGateway
from web.fastapi_app import create_app

def build_production_app():
    # All concrete wiring happens here
    order_repo = PostgresOrderRepository(dsn="postgresql://prod-db/...")
    email = SesEmailSender(region="us-east-1")
    billing = StripeBillingGateway(api_key="sk_live_...")

    place_order = PlaceOrder(repo=order_repo, email=email, billing=billing)
    cancel_order = CancelOrder(repo=order_repo, email=email)

    controller = PlaceOrderController(place_order=place_order)
    return create_app(controllers=[controller])

app = build_production_app()
```

```python
# test_main.py — same architecture, different plugin
from order_management.use_cases import PlaceOrder
from tests.fakes import InMemoryOrderRepository, FakeEmailSender, FakeBillingGateway

def build_test_app():
    order_repo = InMemoryOrderRepository()
    email = FakeEmailSender()
    billing = FakeBillingGateway(should_succeed=True)
    return PlaceOrder(repo=order_repo, email=email, billing=billing)

# Zero production infrastructure required for any unit test.
```

```python
# dev_main.py — development-specific configuration
def build_dev_app():
    # SQLite instead of Postgres, console email instead of SES
    order_repo = SqliteOrderRepository(path=":memory:")
    email = ConsoleEmailSender()    # prints to stdout
    billing = StripeBillingGateway(api_key="sk_test_...")
    # ...
```

## Quick Reference
- Main is the only file with a full import list of concrete classes
- Swap Main → swap entire infrastructure without touching business logic
- Main is a plugin: production, test, development, staging are different Main modules

---