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
The subtotal (excluding VAT) at or above which delivery is free — a mainland-only promise; off-mainland zones pay delivery at any order value. A round figure, env-overridable.
_Avoid_: free delivery minimum, free-ship cutoff.

### Delivery

**Shipping zone**:
The delivery-pricing answer for a UK postcode: mainland, highlands, remote islands, Northern Ireland, or offshore islands — or, outside those, unknown (unparseable) and undeliverable (a place we do not ship to). Off-mainland zones share one delivery price and one transit promise; mainland keeps the standard cost and next-working-day dispatch.
_Avoid_: region, surcharge area, delivery area.

**Delivery postcode**:
The postcode the customer gives before payment (typed on the cart page, or taken from a saved address) that the order's shipping price is derived from. Distinct from the postcode in the collected shipping address, which can in principle disagree.
_Avoid_: shipping postcode, address postcode.

**Priced zone**:
The shipping zone an order's delivery charge was actually computed from, fixed at the moment the Stripe session is created. Recorded on the order so a later mismatch with the delivered-to address is visible.
_Avoid_: charged zone, booked zone.

### Checkout

**Hosted checkout**:
Paying on Stripe's own checkout page, reached by redirect away from afida.com.
_Avoid_: Stripe portal, external checkout.

**On-site checkout**:
Paying on a checkout page afida.com renders itself, with Stripe supplying only the secure payment inputs. The customer never leaves the site.
_Avoid_: embedded checkout (that names Stripe's iframe product, which this is not), custom checkout.

**Zone guard**:
The best-effort check during on-site checkout that stops payment when the address being entered belongs to a different shipping zone than the priced zone, sending the customer back to reprice instead of charging the wrong delivery. Fails open to hosted-checkout behaviour: mismatch recorded, visible after the fact.
_Avoid_: postcode check, address validation.

**Welcome discount**:
The signup 10%-off, applied to the whole order (goods and delivery) before payment begins. Carried by the customer's session from the signup form to checkout; refused for samples-only orders.
_Avoid_: welcome coupon (a coupon is Stripe's internal object; the discount is the customer-facing thing), WELCOME10 (a promotion code's current name, not the concept).

**Promotion code**:
A customer-facing code typed at checkout to claim a discount. Distinct from a coupon, Stripe's internal discount object that a promotion code points at; the two have different identifiers, and conflating them has caused real bugs.
_Avoid_: promo, voucher, coupon code.

### Lead generation

**Sighting**:
The fact that a business identity has been observed in an external register (a food-hygiene FHRSID today; later possibly a Companies House number). Pure record-of-observation, never shown to humans.
_Avoid_: snapshot row, register entry.

**Lead**:
An actionable prospect: a newly opened food business a human might contact. A lead exists only for businesses first sighted after their register's seed run; register backfill is never a lead.
_Avoid_: using "lead" for seeded register rows.

**Seed run**:
The first discovery run against a register source. It records sightings for everything currently in the register and deliberately reports nothing as new.
_Avoid_: initial import, backfill run.

**Lead status**:
Where a lead stands in the outreach lifecycle. `New lead` = nobody has acted on it; `contacted` = at least one outreach of any kind has been sent; `converted` = the business placed an order or opened a trade account; `dismissed` = deliberately not pursued (chain, out of scope, closed).
_Avoid_: pipeline stage, funnel step.
