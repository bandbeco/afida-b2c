# On-Site Checkout (Stripe Custom UI) — Design

**Date:** 2026-07-28
**Status:** Approved (pending spec review + user review)

## Goal

Move checkout onto afida.com instead of redirecting shoppers to Stripe's hosted
Checkout page. Afida renders the whole checkout page (order summary, email,
shipping address, delivery cost, promo code, payment fields); Stripe provides
only the secure payment inputs. Motivations: remove redirect drop-off, keep the
experience on-brand, improve Datafast attribution (no cross-domain hop), and
open the door to future checkout features.

## Approach

Stripe **Checkout Sessions API with custom UI** (`ui_mode: "custom"`, Stripe's
"Elements with Checkout Sessions API"; use whatever enum the pinned Stripe API
version names this mode at implementation time). The server keeps creating a
Checkout Session through the existing `Checkout::SessionBuilder` almost exactly
as today; only the frontend changes from a redirect to an on-site page. Stripe
remains the source of truth for money math (VAT, the taxed shipping line, the
welcome discount), so the runbook's hard-won behaviours — whole-order coupon
math, zero-total `no_payment_required`, `checkout.session.completed` webhook —
carry over unchanged.

Rejected alternatives:

- **Payment Intents + Payment Element:** maximum control, but the app would
  become the sole authority on money math (VAT, shipping, discounts all
  reimplemented), zero-total orders need a special no-PaymentIntent path, and
  the hosted fallback becomes a second, divergent flow. More work and more
  divergence risk than a parity-only v1 needs.
- **Embedded Checkout (`ui_mode: "embedded"`):** cheapest fix for the
  redirect, but it is Stripe's form in an iframe — afida does not own the
  page, which contradicts the goal.

## Scope

In scope (parity with the hosted page, on afida's own page):

- Order summary (products, VAT, delivery line), email, shipping address via
  Address Element, payment via Payment Element.
- Shipping priced exactly as today: a taxed shipping **line item** (not a
  Stripe `shipping_option`) whose price comes from the `ShippingZone` resolved
  from the cart-page delivery postcode, with the mainland-only free-shipping
  threshold. There is no shipping-method choice today and v1 adds none; the
  page shows the delivery cost as a read-only summary line.
- Discounts exactly as today: the welcome discount applied server-side at
  session creation (coupon ID resolved to a promotion code, coupon fallback);
  when no server-side discount applies, a promo-code input on the page wired
  to the checkout SDK's `applyPromotionCode`, replacing the promo box shoppers
  currently get on Stripe's hosted page. Samples-only carts refuse all
  discounts, as today, so they show no promo input.
- Payment methods: cards, Apple Pay / Google Pay (ride on card in the Payment
  Element), Link.
- A new guard hosted checkout cannot have: block confirm when the address
  entered on the page resolves to a different shipping zone than the one the
  session was priced against (see Architecture).
- Feature flag with instant fallback to hosted Checkout.
- Update the stale "Checkout & Orders" section of `docs/developer_guide.md`
  (its `shipping_options` snippet describes a flow that no longer exists)
  alongside this work.

Out of scope (later enhancements):

- Editing the cart on the checkout page (summary is read-only; a back link
  returns to the cart).
- Shipping-method choice, order notes, custom fields, BNPL.
- Repricing shipping on the checkout page itself (postcode capture stays on
  the cart page; see below).
- Any change to `#success`, `Checkout::OrderCreator`, the webhook handler,
  emails, Telegram notification, or analytics events.

## Architecture

### Where the flag lives

The flag is checked in `CheckoutsController#create` only.

- **Flag off:** exactly today's behaviour — build a hosted session via
  `Checkout::SessionBuilder`, redirect to `session.url`.
- **Flag on:** build the session in custom mode (same builder, see Components)
  and render the checkout page instead of redirecting, passing the session's
  `client_secret` to the view.

All of `#create`'s existing guards and side effects run identically in both
modes and are unchanged: the empty-cart guard, the `deliverable_destination?`
postcode gate, the `checkout.started` and `cart.checkout_initiated` events,
the invalid-discount cleanup, `session[:selected_address_id]`, and the 10/min
rate limit. The only rendering difference: when `#create` renders instead of
redirecting, the invalid-discount alert uses `flash.now`.

### Shipping price and the delivery postcode

Parity, stated explicitly because it is the money path: line-item prices
(including the shipping line) are fixed at session creation from the postcode
captured on the cart page, resolved via `delivery_postcode_for` (typed
postcode wins over selected address, default address last; nil prices as
mainland). The session's `metadata.shipping_zone` continues to record the zone
the order was priced against. This is today's consciously-accepted model — the
address collected during payment can, in principle, disagree with the priced
zone, and the order records both so a mismatch is visible after the fact.

Because afida now renders the page, v1 closes most of that window: when the
Address Element's postcode changes, the Stimulus controller asks a small
read-only endpoint (`GET /shipping_zone?postcode=…`, outside `#create`'s rate
limit) for the zone. If it differs from the session's priced zone (embedded in
the page as a data attribute), the controller disables confirm and shows a
message linking back to the cart, where updating the delivery postcode
reprices the order as today. This guard is client-side and best-effort; if it
fails open, behaviour degrades to exactly today's hosted behaviour, no worse.

### After payment

Everything after payment is untouched. The custom-mode session's `return_url`
is the existing success URL with `?session_id={CHECKOUT_SESSION_ID}`, so
`CheckoutsController#success` runs unchanged: the retrieve with
`expand: ["collected_information", "line_items.data.price.product"]`, the
duplicate-order guards, `Checkout::OrderCreator`, cart clearing, emails,
Telegram, events, and the webhook race handling. The success flow depends on
`Current.cart`, which is unaffected since checkout never leaves afida's
domain. The staging checklist verifies `collected_information` is populated
from Address Element input the same way the hosted form populates it.

### On the page

Stripe.js's `initCheckout(clientSecret)` binds to the session. Afida renders
the order summary (server-rendered from the cart), email field, promo-code
input, and back-to-cart link with its own markup in the shop's existing layout
and styles; Stripe's Address Element (shipping mode) and Payment Element
provide the secure inputs. The SDK is the client-side source of truth for
totals: promo-code application goes through `applyPromotionCode` and displayed
totals re-render from the session state the SDK reports, so the page cannot
diverge from what Stripe charges.

One-time setup outside code: register afida.com and the staging domain for
Apple Pay in the Stripe dashboard (sandbox and live). This is a rollout
checklist item, not just prose: a missed live-domain registration silently
hides the wallet button rather than erroring.

## Components

Server side (changes to existing code):

- **`Checkout::SessionBuilder`:** gains a mode (e.g. `ui_mode:` keyword,
  hosted by default). Custom mode swaps `success_url`/`cancel_url` for
  `return_url` and widens payment methods (below). Everything else is shared
  by construction, not duplicated: line items with the prepended taxed
  shipping line, zone resolution, `metadata` (cart, discount, Datafast IDs,
  `shipping_zone`), discount application including `allow_promotion_codes` on
  the no-code path and the samples-only refusal, customer details
  (`client_reference_id`, `customer`/`customer_email`, Stripe customer sync),
  and the `Result` invalid-discount signalling.
- **Payment methods:** the builder currently pins
  `payment_method_types: ["card"]`. Custom mode uses card + Link (wallets ride
  on card), leaving the hosted branch untouched. Whether that's expressed as
  `payment_method_types: ["card", "link"]` or dashboard-managed payment
  methods is an implementation choice; the constraint is that hosted-mode
  sessions are byte-for-byte unaffected. Note `#success` emits
  `payment_method_types&.first` in the `checkout.completed` event, so Link
  payments may report a different value than hosted mode did — an expected
  analytics shift, not a regression.
- **`CheckoutsController#create`:** branches on the flag as above.
- **Zone endpoint:** a small controller action wrapping `ShippingZone.for`,
  returning the zone for a postcode. Read-only, no session state.
- **Flag:** an ENV var (e.g. `ONSITE_CHECKOUT`), read through one helper
  (`onsite_checkout_enabled?`) so flipping back is an env change plus
  redeploy, no code change. If the shop already has a settings pattern, the
  implementation plan uses that instead.

Client side (the new work):

- **Checkout view:** two-column page (order summary + form) in the shop's
  existing layout and styles. Order summary is server-rendered ERB from the
  cart, read-only in v1, with the priced shipping zone as a data attribute.
- **One Stimulus controller (`onsite-checkout`):** initializes `initCheckout`
  with the client secret, mounts Payment Element and Address Element into
  targets, updates email on the session, watches address changes for the zone
  guard, applies/removes promo codes via the SDK, subscribes to session
  changes to re-render totals, and calls `confirm()` on submit with inline
  error display.
- Stripe.js stays loaded from Stripe's CDN (required by Stripe; already the
  case today).

No new models, no migrations: orders are still created from the completed
session exactly as now.

## Data flow

Cart page (postcode already captured) → POST `CheckoutsController#create` →
guards run, events fire, custom-mode session created → checkout page renders
with client secret → shopper fills email/address (zone guard watches), applies
promo code if any, pays → SDK `confirm()` → Stripe redirects to the existing
success URL with the session ID → order created (or the webhook races it, as
today, guarded against duplicates).

## Error handling

- **Payment declined / validation errors:** `confirm()` returns the error;
  the Stimulus controller shows it inline above the pay button and re-enables
  it. Stripe handles 3DS challenges itself.
- **Zone mismatch:** confirm disabled with a message linking back to the cart
  to reprice (see Architecture). Fails open to today's behaviour.
- **Invalid promo code:** `applyPromotionCode` rejects; show the SDK's error
  inline by the promo input. (The server-applied welcome discount keeps its
  existing invalid-coupon path: flash + continue without discount.)
- **Stale session** (sessions expire after 24h; cart changed in another tab):
  the checkout page is rendered fresh from `#create` on every visit, so each
  visit gets a session matching the current cart. A confirm on an expired
  session surfaces an SDK error; the inline message links back to the cart to
  start again, which mints a new session.
- **JS fails to load / SDK init error:** the page shows a fallback message
  with a link back to the cart; if problems persist, flip the flag and
  everyone is back on hosted Checkout.
- **Zero-total orders:** the session completes with `no_payment_required` as
  today; existing gates already accept both statuses.
- **Abandoned checkout:** nothing to clean up; unconfirmed sessions expire,
  same as abandoned hosted sessions today. `#cancel` remains for the hosted
  fallback; the on-site page's back-to-cart affordance is a plain link.

## Rollout

Ship behind the flag with hosted Checkout as instant fallback. Verify on
staging (flag on) against Stripe sandbox, then enable in production. Keep the
hosted path wired until the on-site flow has processed real orders without
incident; removing the flag and hosted branch is a later cleanup task.

## Testing

- **Builder tests:** custom mode produces the same params as hosted mode
  except `return_url` and payment methods — pinning the **shipping line
  item** specifically (price by zone, tax rate, prepended position), the
  discount branches (welcome code, no code → `allow_promotion_codes`,
  samples-only refusal, invalid coupon), metadata, and customer details.
  Include the invalid-coupon fallback as a rendering case: in custom mode
  that branch shows both the `flash.now` alert and the promo input (the
  shopper can retype the code), and a test should pin that combination.
  Existing hosted-mode builder tests must pass unchanged.
- **Controller tests:** flag off → redirect to Stripe URL (existing tests keep
  passing); flag on → renders the checkout page with the client secret,
  guards still fire (empty cart, undeliverable postcode, rate limit), invalid
  discount uses `flash.now`.
- **Zone endpoint test:** postcode → zone mapping, including unparseable
  postcodes.
- **Success + webhook:** existing tests already cover order creation from a
  completed session; unchanged, they double as regression cover for both
  modes.
- **System test:** flag on, walk from cart (with postcode) to the checkout
  page and assert summary, delivery line, promo input, and Stripe mount
  points render. Driving the real Payment Element iframe in CI is flaky by
  design, so confirm-and-pay is covered manually on staging (Stripe test
  mode) before flipping the flag in production.
- **Manual staging checklist:** card, Apple Pay, Link, welcome discount,
  shopper-typed promo code, invalid promo code, 100%-off code (zero total),
  samples-only cart (shipping charged, no promo input), off-mainland postcode
  priced at £25, zone-mismatch guard (price as mainland, enter Highlands
  postcode on page), declined card, `collected_information` present on the
  resulting order.
