# Staged diff under review — pure Python, clean

All task stamps present (see `REVIEW-LOG.md`). This is a small, correct Python change: a new
pure function plus its behavioral test. A proportional review should detect the Python stack,
load only `checks-universal.md`, and likely return a PASS / no must-fix verdict.

```diff
diff --git a/src/brightcart/shipping.py b/src/brightcart/shipping.py
index 1a2b3c4..5d6e7f8 100644
--- a/src/brightcart/shipping.py
+++ b/src/brightcart/shipping.py
@@ -1,6 +1,11 @@
 """Shipping helpers."""

 FREE_SHIPPING_THRESHOLD = 50.00


 def qualifies_for_free_shipping(total: float) -> bool:
     return total >= FREE_SHIPPING_THRESHOLD
+
+
+def shipping_fee(total: float, flat_fee: float = 4.99) -> float:
+    """Flat fee below the free-shipping threshold, otherwise zero."""
+    return 0.0 if qualifies_for_free_shipping(total) else flat_fee
diff --git a/tests/test_shipping.py b/tests/test_shipping.py
index 2222222..3333333 100644
--- a/tests/test_shipping.py
+++ b/tests/test_shipping.py
@@ -1,3 +1,11 @@
 from brightcart.shipping import qualifies_for_free_shipping, shipping_fee


 def test_qualifies_at_threshold():
     assert qualifies_for_free_shipping(50.00) is True
+
+
+def test_shipping_fee_waived_at_threshold():
+    assert shipping_fee(50.00) == 0.0
+
+
+def test_shipping_fee_charged_below_threshold():
+    assert shipping_fee(49.99) == 4.99
```
