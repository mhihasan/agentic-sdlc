# Chapter 17: Behavioral — Chain of Responsibility

## Summary
Chain of Responsibility passes a request along a chain of handlers, where each handler
decides either to process the request or to pass it to the next handler in the chain.
This decouples the sender of a request from its receivers — the sender doesn't know which
handler will process it, and handlers don't know about each other beyond the "next" link.
The pattern is the right tool for ordered processing pipelines (middleware), multi-level
approval workflows, and event bubbling systems where the set of handlers and their order
must vary independently of the request.

## Key Principles
- **Handler interface**: Each handler implements the same interface with a `handle(request)` method and a reference to the next handler.
- **Pass or process**: Each handler decides to handle the request, pass it on, or both.
- **Chain assembly**: The chain is assembled by the client (or a Director); handlers don't know the full chain.
- **No guarantee of handling**: Unlike a command routed to a specific receiver, a CoR request might not be handled by anyone — design for this case.
- **Order matters**: The sequence of handlers in the chain determines which gets priority.

## Python Example

```python
from __future__ import annotations
from typing import Optional, Protocol
from dataclasses import dataclass

# ❌ Bad: Monolithic handler with deeply nested if-elif chains
def authenticate_bad(request: dict) -> str:
    if not request.get("auth_token"):
        return "REJECTED: no token"
    elif request.get("auth_token") == "revoked":
        return "REJECTED: revoked token"
    elif request.get("role") != "admin":
        return "REJECTED: not admin"
    elif not request.get("payload"):
        return "REJECTED: empty payload"
    else:
        return "ACCEPTED"
# Adding a new check requires editing this function — brittle


# ✅ Good: Chain of Responsibility

@dataclass
class Request:
    token: Optional[str]
    role: str
    payload: Optional[dict]

class Handler(Protocol):
    def set_next(self, handler: "Handler") -> "Handler": ...
    def handle(self, request: Request) -> Optional[str]: ...


class BaseHandler:
    """Mixin that manages next-handler plumbing."""
    def __init__(self) -> None:
        self._next: Optional["BaseHandler"] = None

    def set_next(self, handler: "BaseHandler") -> "BaseHandler":
        self._next = handler
        return handler  # return handler to enable fluent chaining

    def handle(self, request: Request) -> Optional[str]:
        if self._next:
            return self._next.handle(request)
        return None  # end of chain — no handler consumed the request


class AuthTokenHandler(BaseHandler):
    def handle(self, request: Request) -> Optional[str]:
        if not request.token:
            return "REJECTED: missing auth token"
        if request.token == "revoked":
            return "REJECTED: token has been revoked"
        return super().handle(request)  # pass to next


class RoleHandler(BaseHandler):
    def __init__(self, required_role: str) -> None:
        super().__init__()
        self._required = required_role

    def handle(self, request: Request) -> Optional[str]:
        if request.role != self._required:
            return f"REJECTED: requires role '{self._required}', got '{request.role}'"
        return super().handle(request)


class PayloadHandler(BaseHandler):
    def handle(self, request: Request) -> Optional[str]:
        if not request.payload:
            return "REJECTED: empty payload"
        return "ACCEPTED"  # terminal handler — consumed


# Assemble the chain
auth    = AuthTokenHandler()
role    = RoleHandler("admin")
payload = PayloadHandler()

auth.set_next(role).set_next(payload)

# Test the chain
r1 = Request(token=None, role="admin", payload={"action": "delete"})
assert auth.handle(r1) == "REJECTED: missing auth token"

r2 = Request(token="valid", role="user", payload={"action": "delete"})
assert auth.handle(r2) == "REJECTED: requires role 'admin', got 'user'"

r3 = Request(token="valid", role="admin", payload=None)
assert auth.handle(r3) == "REJECTED: empty payload"

r4 = Request(token="valid", role="admin", payload={"action": "delete"})
assert auth.handle(r4) == "ACCEPTED"


# ── Middleware pipeline variant (web framework style) ─────────────────────

from typing import Callable

Middleware = Callable[[Request, Callable], Optional[str]]

def logging_middleware(request: Request, next_fn: Callable) -> Optional[str]:
    print(f"[LOG] Handling request with role={request.role}")
    result = next_fn(request)
    print(f"[LOG] Result: {result}")
    return result

def auth_middleware(request: Request, next_fn: Callable) -> Optional[str]:
    if not request.token:
        return "REJECTED: no token"
    return next_fn(request)

def handler(request: Request) -> str:
    return f"HANDLED: {request.payload}"

# Chain built as a composed callable
pipeline = lambda req: logging_middleware(
    req, lambda r: auth_middleware(r, handler)
)
result = pipeline(Request(token="tok", role="admin", payload={"x": 1}))
assert "HANDLED" in result
```

## Quick Reference
- **Intent**: Pass request along a handler chain; each handler processes or forwards
- **Use when**: Multiple objects may handle a request; handler set/order varies at runtime
- **Chain assembly**: The client (not handlers) links them: `a.set_next(b).set_next(c)`
- **Pass-through base class**: `BaseHandler.handle()` delegates to `_next` if set — subclasses call `super().handle(request)` to forward
- **No handler**: Design for the case where no handler processes the request (return `None`)
- **vs Command**: Command routes to a specific receiver; CoR passes until someone handles it
- **vs Decorator**: Decorator always passes through AND adds behaviour; CoR may stop the chain
- **Real uses**: Python WSGI/ASGI middleware, Django request handlers, logging level hierarchy, event bubbling in GUIs, AWS Lambda event pipelines
