# Chapter 33: Case Study — Video Sales

## Summary
A complete worked example deriving Clean Architecture from requirements. Starting from actor analysis and use cases, Martin constructs the component dependency graph, assigns components to rings, and verifies the Dependency Rule is satisfied. Each architectural decision is traced back to a specific use case or actor — not to framework conventions.

## The Derivation Process

```
1. Identify actors
   → Viewer, Author, Administrator, Purchaser

2. Identify use cases per actor
   → Viewer:     Watch video, Browse catalogue
   → Author:     Upload video, Set price, View earnings
   → Admin:      Manage accounts, Issue refunds
   → Purchaser:  Buy video, View purchase history

3. Apply CCP: each actor's use cases form a component
   → viewer_component, author_component, admin_component, purchase_component

4. Assign to rings
   → Ring 1 (Entities):            Video, Purchase, User
   → Ring 2 (Use Cases):           WatchVideo, PurchaseVideo, UploadVideo, …
   → Ring 3 (Interface Adapters):  VideoController, PurchasePresenter, S3Gateway
   → Ring 4 (Frameworks & Drivers): FastAPI, PostgreSQL, Stripe, S3

5. Verify: all source-code dependencies point only inward → Dependency Rule satisfied
```

## Python Example

```python
from dataclasses import dataclass, replace
from decimal import Decimal
from typing import Protocol

# ======== RING 1: Entities — pure domain, no infrastructure ========

@dataclass(frozen=True)
class Video:
    video_id: str
    author_id: str
    title: str
    price: Decimal
    is_published: bool = False

    def publish(self) -> "Video":
        return replace(self, is_published=True)

    def update_price(self, new_price: Decimal) -> "Video":
        if new_price < Decimal("0"):
            raise ValueError("Price cannot be negative")
        return replace(self, price=new_price)

@dataclass(frozen=True)
class Purchase:
    purchase_id: str
    user_id: str
    video_id: str
    amount_paid: Decimal

# Entity tests — no infrastructure required
v = Video("v1", "author-1", "Clean Architecture", Decimal("29.99"))
published = v.publish()
assert published.is_published
assert v.is_published is False          # original unchanged (frozen)


# ======== RING 2: Use Cases — Protocols defined here ========

class VideoRepository(Protocol):
    def find(self, video_id: str) -> Video | None: ...
    def save(self, video: Video) -> None: ...

class PurchaseRepository(Protocol):
    def save(self, purchase: Purchase) -> None: ...
    def has_purchased(self, user_id: str, video_id: str) -> bool: ...

class BillingGateway(Protocol):
    def charge(self, user_id: str, amount: Decimal) -> bool: ...

@dataclass
class PurchaseVideoRequest:
    user_id: str
    video_id: str

@dataclass
class PurchaseVideoResponse:
    success: bool
    purchase_id: str | None = None
    error: str | None = None

class PurchaseVideo:
    def __init__(
        self,
        videos: VideoRepository,
        purchases: PurchaseRepository,
        billing: BillingGateway,
    ) -> None:
        self._videos    = videos
        self._purchases = purchases
        self._billing   = billing

    def execute(self, req: PurchaseVideoRequest) -> PurchaseVideoResponse:
        if self._purchases.has_purchased(req.user_id, req.video_id):
            return PurchaseVideoResponse(success=False, error="Already purchased")

        video = self._videos.find(req.video_id)
        if not video or not video.is_published:
            return PurchaseVideoResponse(success=False, error="Video unavailable")

        if not self._billing.charge(req.user_id, video.price):
            return PurchaseVideoResponse(success=False, error="Payment failed")

        purchase = Purchase(
            purchase_id=f"p-{req.user_id}-{req.video_id}",
            user_id=req.user_id,
            video_id=req.video_id,
            amount_paid=video.price,
        )
        self._purchases.save(purchase)
        return PurchaseVideoResponse(success=True, purchase_id=purchase.purchase_id)


# ======== Tests — zero infrastructure ========

class FakeVideoRepository:
    def __init__(self, videos: dict[str, Video]) -> None:
        self._store = videos
    def find(self, video_id: str) -> Video | None:
        return self._store.get(video_id)
    def save(self, video: Video) -> None:
        self._store[video.video_id] = video

class FakePurchaseRepository:
    def __init__(self) -> None:
        self._store: dict[str, Purchase] = {}
    def save(self, p: Purchase) -> None:
        self._store[p.purchase_id] = p
    def has_purchased(self, user_id: str, video_id: str) -> bool:
        return any(p.user_id == user_id and p.video_id == video_id
                   for p in self._store.values())

class FakeBillingGateway:
    def __init__(self, succeeds: bool = True) -> None:
        self._succeeds = succeeds
    def charge(self, user_id: str, amount: Decimal) -> bool:
        return self._succeeds

def test_successful_purchase() -> None:
    video = Video("v1", "author-1", "CA Book", Decimal("29.99"), is_published=True)
    use_case = PurchaseVideo(
        videos=FakeVideoRepository({"v1": video}),
        purchases=FakePurchaseRepository(),
        billing=FakeBillingGateway(succeeds=True),
    )
    resp = use_case.execute(PurchaseVideoRequest("user-1", "v1"))
    assert resp.success
    assert resp.purchase_id is not None

def test_unpublished_video_rejected() -> None:
    video = Video("v1", "author-1", "Draft", Decimal("9.99"), is_published=False)
    use_case = PurchaseVideo(
        FakeVideoRepository({"v1": video}),
        FakePurchaseRepository(),
        FakeBillingGateway(),
    )
    resp = use_case.execute(PurchaseVideoRequest("user-1", "v1"))
    assert not resp.success
    assert resp.error == "Video unavailable"

def test_payment_failure_rejected() -> None:
    video = Video("v1", "author-1", "CA Book", Decimal("29.99"), is_published=True)
    use_case = PurchaseVideo(
        FakeVideoRepository({"v1": video}),
        FakePurchaseRepository(),
        FakeBillingGateway(succeeds=False),
    )
    resp = use_case.execute(PurchaseVideoRequest("user-1", "v1"))
    assert not resp.success
    assert resp.error == "Payment failed"

test_successful_purchase()
test_unpublished_video_rejected()
test_payment_failure_rejected()
print("All video sales case study tests pass ✅")
```

## Quick Reference
- Derive architecture from actors and use cases, not framework conventions
- Apply CCP: each actor's use cases form a natural component boundary
- Entities are the most stable — shared across use cases, change least
- Protocols defined in ring 2 (use case layer), implementations in ring 4
- Verify: draw the dependency graph — all arrows must point inward
