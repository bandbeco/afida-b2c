# Architecture Decision Records

Decisions that are hard to reverse, surprising without context, and the result of a real trade-off. One decision per file, sequentially numbered.

* [Lead discovery via register snapshot diffing](/adr/0001-lead-discovery-via-register-diffing.md) - Why newness is first-seen diffing (Sighting vs Lead split) rather than the register's own status, and why Companies House waits.
* [On-site checkout builds on Checkout Sessions](/adr/0002-onsite-checkout-on-checkout-sessions.md) - Why the on-site checkout kept Checkout Sessions in custom UI mode rather than Payment Intents: Stripe remains the sole authority on VAT, shipping, discount, and zero-total math.
