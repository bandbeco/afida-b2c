# On-site checkout builds on Checkout Sessions (custom UI), not Payment Intents

When checkout moved onto afida.com (2026-07, on-site checkout spec), we kept
creating Stripe Checkout Sessions — via the existing `Checkout::SessionBuilder`
in `ui_mode: "custom"` — rather than switching to the Payment Intents + Payment
Element integration that most custom checkout pages use. The reason: Stripe
stays the sole authority on money math. VAT via tax rates, the taxed shipping
line item, whole-order discounts, and zero-total orders (`no_payment_required`)
all keep the exact semantics the shop has already debugged in production, and
the `checkout.session.completed` webhook and `#success` order-creation path run
unchanged for both modes.

## Considered Options

- **Payment Intents + Payment Element** — rejected: the app would become the
  only implementation of VAT, shipping, and discount math (today `OrderTotals`
  only mirrors Stripe for preview); a £0 PaymentIntent cannot exist, so
  zero-total orders need a bespoke path; and the hosted fallback would become a
  second, divergent flow instead of the same builder with a different
  `ui_mode`.
- **Embedded Checkout (`ui_mode: "embedded"`)** — rejected: Stripe's form in an
  iframe; afida does not own the page, which was the point.

## Consequences

Don't "modernise" this to Payment Intents without accepting that VAT, shipping,
discount, and zero-total semantics must all be reimplemented and re-verified
app-side. The hosted fallback stays cheap only while both modes share one
session builder.
