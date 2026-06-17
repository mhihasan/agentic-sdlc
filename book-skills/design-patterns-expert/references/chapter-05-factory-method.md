# Chapter 5: Creational — Factory Method

## Summary
Factory Method defines an interface for creating an object but delegates the decision of
which concrete class to instantiate to subclasses. The "creator" declares the factory method
returning a "product" interface; each concrete creator overrides it to produce its own product
variant. The pattern eliminates direct `new ConcreteProduct()` calls scattered in client code,
replacing them with a single injection point that is easy to extend. The canonical trigger is
when your code must create objects whose exact type is unknown at design time or must vary
by configuration/environment.

## Key Principles
- **Decouple construction from use**: Client code works with the Product interface; it never calls `ConcreteProduct()` directly.
- **Single extension point**: Adding a new product type requires only a new Creator subclass — no edits to existing code (OCP).
- **Also known as Virtual Constructor**: The factory method is the hook subclasses use to change the class of objects created.
- **Return type is the interface**: The factory method's return type must be the Product Protocol/ABC — never a concrete class.
- **Named constructors as Pythonic alternative**: For simple cases, `@classmethod` factory methods on the product itself often suffice.

## Python Example

```python
from typing import Protocol
from dataclasses import dataclass

# ❌ Bad: Logistics app hardcoded to Truck — adding Ship requires editing this class
class LogisticsAppBad:
    def plan_delivery(self) -> None:
        truck = Truck()  # coupled to concrete — must edit for every new transport type
        truck.deliver()


# ✅ Good: Factory Method pattern

class Transport(Protocol):
    def deliver(self) -> str: ...

class Truck:
    def deliver(self) -> str:
        return "Delivering by land in a truck"

class Ship:
    def deliver(self) -> str:
        return "Delivering by sea in a ship"

class AirFreight:
    def deliver(self) -> str:
        return "Delivering by air"


# Creator declares the factory method
class Logistics:
    def create_transport(self) -> Transport:
        raise NotImplementedError

    def plan_delivery(self) -> str:
        transport = self.create_transport()  # calls the hook — never knows the concrete type
        return transport.deliver()


# Concrete creators override the factory method
class RoadLogistics(Logistics):
    def create_transport(self) -> Transport:
        return Truck()

class SeaLogistics(Logistics):
    def create_transport(self) -> Transport:
        return Ship()

class AirLogistics(Logistics):
    def create_transport(self) -> Transport:
        return AirFreight()


# Client code works with Logistics interface — no concrete imports needed
def client(logistics: Logistics) -> str:
    return logistics.plan_delivery()

assert client(RoadLogistics()) == "Delivering by land in a truck"
assert client(SeaLogistics())  == "Delivering by sea in a ship"
assert client(AirLogistics())  == "Delivering by air"


# ── Pythonic variant: @classmethod named constructors ──────────────────────

class Connection:
    def __init__(self, host: str, port: int, tls: bool) -> None:
        self.host = host
        self.port = port
        self.tls = tls

    @classmethod
    def from_url(cls, url: str) -> "Connection":
        # parse url — factory logic lives on the class itself
        host, port = url.split(":")
        return cls(host, int(port), tls=False)

    @classmethod
    def secure(cls, host: str) -> "Connection":
        return cls(host, 443, tls=True)

conn = Connection.from_url("db.example.com:5432")
tls  = Connection.secure("api.example.com")
assert tls.port == 443
assert tls.tls is True
```

## Quick Reference
- **Intent**: Define object creation interface in base class; subclasses decide concrete type
- **Use when**: exact product type is unknown at design time, or varies by subclass/config
- **Structure**: `Creator.create_product()` → `ConcreteCreator` overrides → returns `ConcreteProduct`
- **Python idiom**: `@classmethod` named constructors for simple single-class factories
- **vs Abstract Factory**: Factory Method creates one product family member; Abstract Factory creates entire families
- **vs Builder**: Builder focuses on step-by-step construction; Factory Method focuses on which type to create
- **OCP benefit**: New product = new Creator subclass + new Product class; zero edits to client
- **Smell it replaces**: `if config == "sea": return Ship()` scattered across caller code
