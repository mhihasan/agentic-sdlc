# Chapter 30: The Database Is a Detail

## Summary
The database is an I/O device — a mechanism for storing and retrieving data. The data *model* (what entities exist, how they relate) is architecturally significant. The *database technology* (PostgreSQL vs DynamoDB vs MongoDB) is not. Business objects must not know about table structure, query language, or ORM behaviour. The persistence layer is the outermost ring — it implements repository Protocols defined by the use case layer.

## Key Principles
- **Data model ≠ database technology**: Entity structure is a business concern; storage engine is an implementation detail.
- **Repository pattern**: Use cases depend on Repository Protocols. Concrete ORM/SQL implementations live in the outermost ring.
- **ORM objects must not cross boundaries**: Translate to pure domain objects at the repository layer — never pass SQLAlchemy models into use cases.
- **The relational model is a detail**: Don't let schema design dictate your domain objects.

## Python Example

```python
# ❌ Bad: ORM model bleeds into use case — business logic coupled to SQLAlchemy
from sqlalchemy import Column, Integer, String
from sqlalchemy.orm import DeclarativeBase

class Base(DeclarativeBase): pass

class OrderModel(Base):          # SQLAlchemy ORM model used as domain object
    __tablename__ = "orders"
    id = Column(Integer, primary_key=True)
    user_id = Column(String)
    total = Column(Integer)

def apply_discount(order: OrderModel, pct: float) -> OrderModel:
    order.total = int(order.total * (1 - pct))  # mutates ORM object in use case
    return order
# Use case depends on SQLAlchemy. Switching to DynamoDB: rewrite every use case.
```

```python
# ✅ Good: Repository Protocol — ORM stays in the outer ring
from dataclasses import dataclass, replace
from typing import Protocol

# ---- Ring 1: Domain entity — pure Python, no ORM ----
@dataclass(frozen=True)
class Order:
    order_id: str
    user_id: str
    total: float

    def with_discount(self, pct: float) -> "Order":
        return replace(self, total=self.total * (1 - pct))

# ---- Ring 2: Repository Protocol — defined by use case layer ----
class OrderRepository(Protocol):
    def find(self, order_id: str) -> Order | None: ...
    def save(self, order: Order) -> None: ...

# ---- Ring 2: Use case — imports only domain objects and Protocol ----
class ApplyDiscount:
    def __init__(self, repo: OrderRepository) -> None:
        self._repo = repo

    def execute(self, order_id: str, pct: float) -> Order:
        order = self._repo.find(order_id)
        if order is None:
            raise ValueError(f"Order {order_id} not found")
        discounted = order.with_discount(pct)
        self._repo.save(discounted)
        return discounted

# ---- Ring 4: SQLAlchemy implementation — ORM detail lives here only ----
from sqlalchemy.orm import Session

class SqlAlchemyOrderRepository:         # satisfies OrderRepository via duck typing
    def __init__(self, session: Session) -> None:
        self._session = session

    def find(self, order_id: str) -> Order | None:
        row = self._session.get(OrderModel, order_id)   # ORM query
        if row is None:
            return None
        return Order(order_id=str(row.id), user_id=row.user_id, total=row.total)  # translate

    def save(self, order: Order) -> None:
        row = self._session.get(OrderModel, order.order_id)
        row.total = int(order.total)
        self._session.flush()

# ---- Ring 4: DynamoDB implementation — swap without changing use case ----
import boto3

class DynamoOrderRepository:            # satisfies same OrderRepository Protocol
    def __init__(self, table_name: str) -> None:
        self._table = boto3.resource("dynamodb").Table(table_name)

    def find(self, order_id: str) -> Order | None:
        resp = self._table.get_item(Key={"order_id": order_id})
        item = resp.get("Item")
        if not item:
            return None
        return Order(order_id=item["order_id"], user_id=item["user_id"], total=float(item["total"]))

    def save(self, order: Order) -> None:
        self._table.put_item(Item={
            "order_id": order.order_id,
            "user_id": order.user_id,
            "total": str(order.total),
        })

# ---- In-memory for tests ----
class InMemoryOrderRepository:
    def __init__(self) -> None:
        self._store: dict[str, Order] = {}

    def find(self, order_id: str) -> Order | None:
        return self._store.get(order_id)

    def save(self, order: Order) -> None:
        self._store[order.order_id] = order

def test_apply_discount() -> None:
    repo = InMemoryOrderRepository()
    repo.save(Order("o1", "u1", 100.0))
    result = ApplyDiscount(repo).execute("o1", pct=0.1)
    assert result.total == 90.0
    assert repo.find("o1").total == 90.0
```

## Quick Reference
- Database = I/O device, ring 4 only
- Repository Protocol lives in ring 2 (use case); implementation in ring 4
- Never pass ORM objects into use cases — translate to `@dataclass` domain objects at the boundary
- Switching PostgreSQL → DynamoDB: write a new ring-4 class, zero changes to rings 1–2
