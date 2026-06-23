# afida shop

The domain glossary for an eco-friendly packaging e-commerce shop (UK, B2B-leaning). This file is a glossary only: it names concepts and the words we use for them, not how they are implemented.

## Language

### Money

**Order totals**:
The money quartet shown for a basket or order: subtotal, VAT, shipping, total. Derived from a subtotal by applying the VAT rate and the free-shipping rule. The same four numbers must be computed one way everywhere they appear.
_Avoid_: amounts, pricing, cost breakdown.

**Deferred shipping**:
The stance taken before a customer reaches Stripe: the shipping line is not yet known, so it is omitted and the total is subtotal plus VAT only. Used by the cart and reorder previews, which show "calculated at checkout".
_Avoid_: pending shipping, TBD shipping.

**Charged shipping**:
The stance taken when shipping is fixed at order time: the free-shipping threshold decides whether shipping is free or the standard cost, and the total includes it. Used when a reorder snapshot is frozen.
_Avoid_: final shipping, applied shipping.

**Subtotal**:
The sum of line totals before VAT and before shipping. Each surface knows how to sum its own lines (cart items, snapshot lines, schedule items); the resulting figure is the input to the order totals.
_Avoid_: net, pre-tax amount, goods total.

**Free-shipping threshold**:
The subtotal (excluding VAT) at or above which standard UK delivery is free. A round figure, env-overridable.
_Avoid_: free delivery minimum, free-ship cutoff.
