# Chapter 7: Creational — Builder

## Summary
Builder separates the construction of a complex object from its representation, so the same
construction process can produce different results. It solves the "telescoping constructor"
problem — where a class gains more and more optional parameters, forcing callers to pass many
`None`s. A Builder object accumulates configuration through a fluent interface (method chaining)
and only assembles the final object when `build()` is called. An optional Director class
encodes reusable construction sequences without exposing builder internals to clients.

## Key Principles
- **Step-by-step construction**: Each builder method sets one part of the object; call order is controlled.
- **Different representations, same process**: Multiple concrete builders can produce different outputs (HTML doc vs PDF doc) through the same Director sequence.
- **Immutable product**: The product is typically assembled and then delivered as an immutable value object — no partial state leaks out.
- **Director is optional**: The Director encodes common build sequences as named methods; useful when many clients need the same config.
- **vs Factory**: Factory creates objects in one step; Builder constructs step-by-step, useful for complex objects with many optional parts.

## Python Example

```python
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Optional

# ❌ Bad: Telescoping constructor — callers must know which args are optional
class QueryBad:
    def __init__(self, table, select=None, where=None, order_by=None,
                 limit=None, offset=None, joins=None, group_by=None):
        ...
# Client: QueryBad("users", ["id","name"], "age > 18", "name", 50, 0, None, None)
# Positional args are error-prone; meaning of each position is invisible


# ✅ Good: Builder pattern

@dataclass(frozen=True)
class Query:
    """Immutable product — only Builder can construct it."""
    table: str
    select: tuple[str, ...] = ("*",)
    where: Optional[str] = None
    order_by: Optional[str] = None
    limit: Optional[int] = None
    offset: int = 0
    joins: tuple[str, ...] = field(default_factory=tuple)

    def to_sql(self) -> str:
        cols = ", ".join(self.select)
        sql = f"SELECT {cols} FROM {self.table}"
        for j in self.joins:
            sql += f" JOIN {j}"
        if self.where:
            sql += f" WHERE {self.where}"
        if self.order_by:
            sql += f" ORDER BY {self.order_by}"
        if self.limit:
            sql += f" LIMIT {self.limit}"
        if self.offset:
            sql += f" OFFSET {self.offset}"
        return sql


class QueryBuilder:
    def __init__(self, table: str) -> None:
        self._table = table
        self._select: tuple[str, ...] = ("*",)
        self._where: Optional[str] = None
        self._order_by: Optional[str] = None
        self._limit: Optional[int] = None
        self._offset: int = 0
        self._joins: list[str] = []

    def select(self, *columns: str) -> QueryBuilder:
        self._select = columns
        return self  # fluent interface

    def where(self, condition: str) -> QueryBuilder:
        self._where = condition
        return self

    def order_by(self, column: str) -> QueryBuilder:
        self._order_by = column
        return self

    def limit(self, n: int) -> QueryBuilder:
        self._limit = n
        return self

    def offset(self, n: int) -> QueryBuilder:
        self._offset = n
        return self

    def join(self, clause: str) -> QueryBuilder:
        self._joins.append(clause)
        return self

    def build(self) -> Query:
        return Query(
            table=self._table,
            select=self._select,
            where=self._where,
            order_by=self._order_by,
            limit=self._limit,
            offset=self._offset,
            joins=tuple(self._joins),
        )


# Director encodes common reusable query patterns
class QueryDirector:
    @staticmethod
    def paginated_users(page: int, page_size: int = 20) -> Query:
        return (
            QueryBuilder("users")
            .select("id", "name", "email")
            .where("active = TRUE")
            .order_by("created_at DESC")
            .limit(page_size)
            .offset(page * page_size)
            .build()
        )


# Client code — readable, self-documenting, no positional args to miscount
q1 = (
    QueryBuilder("orders")
    .select("id", "total", "status")
    .where("status = 'pending'")
    .order_by("created_at")
    .limit(100)
    .build()
)
assert "WHERE status = 'pending'" in q1.to_sql()
assert "LIMIT 100" in q1.to_sql()

q2 = QueryDirector.paginated_users(page=2)
assert "OFFSET 40" in q2.to_sql()
assert "LIMIT 20" in q2.to_sql()
```

## Quick Reference
- **Intent**: Construct complex objects step-by-step; same process, different representations
- **Use when**: Object has many optional parameters, complex assembly steps, or multiple valid configurations
- **Fluent interface**: Each setter returns `self` to enable chaining: `builder.a().b().c().build()`
- **Director**: Optional class that encodes named build sequences (e.g., `build_sports_car()`)
- **Immutable product**: `build()` returns a frozen/immutable product — Builder holds mutable state during construction
- **vs Factory Method**: Factory creates in one step; Builder assembles incrementally
- **Python idiom**: `@dataclass(frozen=True)` for the product; Builder class holds mutable interim state
- **Real uses**: SQL query builders, HTTP request builders, test data factories (factory_boy), config builders
