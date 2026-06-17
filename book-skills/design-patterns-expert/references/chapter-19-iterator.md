# Chapter 19: Behavioral — Iterator

## Summary
Iterator provides a standard way to traverse a collection without exposing its underlying
representation (list, tree, graph, database cursor). The client uses `next()` repeatedly
through an Iterator interface, completely unaware of whether the collection is a linked list,
a flat array, or a lazily-fetched database result set. Python has the Iterator pattern
baked into its core: any object implementing `__iter__` and `__next__` is an iterator,
and `for x in collection` is syntactic sugar over this protocol. Understanding the pattern
means understanding Python's iteration model — they are the same thing.

## Key Principles
- **Separation of concerns**: Collection manages storage; Iterator manages traversal. Two responsibilities, two objects.
- **Multiple simultaneous iterators**: Each call to `__iter__` returns a fresh independent iterator, enabling nested loops over the same collection.
- **Lazy evaluation**: `__next__` computes values on demand — enables infinite sequences and memory-efficient pipelines.
- **External vs Internal**: External (pull) iterators let the client drive with `next()`. Internal (push) iterators call a callback per element. Python's `for` loop is external.
- **Python's protocol**: Implement `__iter__` (returns iterator object) and `__next__` (returns next item or raises `StopIteration`).

## Python Example

```python
from __future__ import annotations
from typing import Iterator, Generic, TypeVar, Optional
from dataclasses import dataclass, field

T = TypeVar("T")

# ❌ Bad: Collection exposes its internal structure — client must know it's a list
class WordCollectionBad:
    def __init__(self):
        self.words: list[str] = []  # public field — client iterates raw list

# Client: for i in range(len(coll.words)): print(coll.words[i])
# If WordCollection becomes a tree tomorrow, all clients break


# ✅ Good: Iterator pattern — Python native style

@dataclass
class TreeNode(Generic[T]):
    value: T
    children: list[TreeNode[T]] = field(default_factory=list)


class DepthFirstIterator(Generic[T]):
    """External iterator over a tree using DFS."""
    def __init__(self, root: TreeNode[T]) -> None:
        self._stack: list[TreeNode[T]] = [root]

    def __iter__(self) -> DepthFirstIterator[T]:
        return self

    def __next__(self) -> T:
        if not self._stack:
            raise StopIteration
        node = self._stack.pop()
        # Push children in reverse so leftmost child is processed first
        self._stack.extend(reversed(node.children))
        return node.value


class BreadthFirstIterator(Generic[T]):
    """External iterator over a tree using BFS."""
    def __init__(self, root: TreeNode[T]) -> None:
        from collections import deque
        self._queue: deque[TreeNode[T]] = deque([root])

    def __iter__(self) -> BreadthFirstIterator[T]:
        return self

    def __next__(self) -> T:
        if not self._queue:
            raise StopIteration
        node = self._queue.popleft()
        self._queue.extend(node.children)
        return node.value


# Build a tree
#       a
#      / \
#     b   c
#    / \
#   d   e

root = TreeNode("a", [
    TreeNode("b", [TreeNode("d"), TreeNode("e")]),
    TreeNode("c"),
])

dfs = list(DepthFirstIterator(root))
bfs = list(BreadthFirstIterator(root))
assert dfs == ["a", "b", "d", "e", "c"]
assert bfs == ["a", "b", "c", "d", "e"]

# Multiple independent iterators over the same tree
iter1 = DepthFirstIterator(root)
iter2 = DepthFirstIterator(root)
assert next(iter1) == "a"
assert next(iter2) == "a"
next(iter1)
assert next(iter1) == "d"  # iter1 advanced independently of iter2


# ── Pythonic: generator as lazy iterator ─────────────────────────────────

def fibonacci() -> Iterator[int]:
    """Infinite lazy sequence — memory cost is O(1) regardless of how many values consumed."""
    a, b = 0, 1
    while True:
        yield a
        a, b = b, a + b

fib = fibonacci()
first_10 = [next(fib) for _ in range(10)]
assert first_10 == [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]


# ── Database cursor as Iterator ───────────────────────────────────────────

class PaginatedQueryIterator:
    """Fetches records from DB in pages; presents as a seamless iterator."""
    def __init__(self, query: str, page_size: int = 100) -> None:
        self._query = query
        self._page_size = page_size
        self._buffer: list[dict] = []
        self._offset = 0
        self._exhausted = False

    def __iter__(self) -> PaginatedQueryIterator:
        return self

    def __next__(self) -> dict:
        if not self._buffer:
            if self._exhausted:
                raise StopIteration
            self._buffer = self._fetch_page()
        if not self._buffer:
            raise StopIteration
        return self._buffer.pop(0)

    def _fetch_page(self) -> list[dict]:
        # Simulate a paginated DB query
        if self._offset >= 250:
            self._exhausted = True
            return []
        rows = [{"id": self._offset + i} for i in range(self._page_size)]
        self._offset += self._page_size
        return rows

records = list(PaginatedQueryIterator("SELECT * FROM events", page_size=100))
assert len(records) == 250
```

## Quick Reference
- **Intent**: Traverse a collection sequentially without exposing its internal structure
- **Python protocol**: `__iter__` returns the iterator; `__next__` returns next item or raises `StopIteration`
- **Generator function**: `yield`-based function is the idiomatic Python iterator — lazy, memory-efficient
- **External iterator**: Client drives with `next()` — Python's `for` loop
- **Multiple iterators**: Each `__iter__` call creates a fresh independent iterator object
- **vs Composite**: Iterator traverses a tree built with Composite
- **Lazy pipelines**: Chain generator functions: `filtered = (x for x in data if predicate(x))`
- **Real uses**: Python `range`, `enumerate`, `zip`, Django QuerySet, SQLAlchemy cursor, file line iterator
