# Staged diff under review — pure Python, contains a real bug

All task stamps present (see `REVIEW-LOG.md`). This change has a genuine off-by-one / boundary
bug: `qualifies_for_free_shipping` now uses `>` instead of `>=`, so an order exactly at the
threshold no longer gets free shipping — contradicting the existing test and the intended
behavior. A correct review flags this (at least High severity) and does NOT fix it.

```diff
diff --git a/src/brightcart/shipping.py b/src/brightcart/shipping.py
index 1a2b3c4..9999999 100644
--- a/src/brightcart/shipping.py
+++ b/src/brightcart/shipping.py
@@ -1,6 +1,6 @@
 """Shipping helpers."""

 FREE_SHIPPING_THRESHOLD = 50.00


 def qualifies_for_free_shipping(total: float) -> bool:
-    return total >= FREE_SHIPPING_THRESHOLD
+    return total > FREE_SHIPPING_THRESHOLD
```
