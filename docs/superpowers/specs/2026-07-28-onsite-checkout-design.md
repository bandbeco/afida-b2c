# On-Site Checkout (Stripe Custom UI) — Design

**Date:** 2026-07-28
**Status:** Approved (pending spec review + user review)

## Goal

Move checkout onto afida.com instead of redirecting shoppers to Stripe's hosted
Checkout page. Afida renders the whole checkout page (order summary, email,
shipping address, shipping method, payment fields); Stripe provides only the
secure payment inputs. Motivations: remove redirect drop-off, keep the
experience on-brand, improve Datafast attribution (no cross-domain hop), and
open the door to future checkout features.

## Approach

Stripe **Checkout Sessions API with `ui_mode: "custom"`** (the checkout SDK in
Stripe.js). The server keeps creating a Checkout Session almost exactly as
today; only the frontend changes from a redirect to an on-site page. Stripe
remains the source of truth for money math (VAT, shipping cost, welcome
coupon), so the runbook's hard-won behaviours — whole-order coupon math,
zero-total `no_payment_required`, `checkout.session.completed` webhook — carry
over unchanged.

Rejected alternatives:

- **Payment Intents + Payment Element:** maximum control, but the app would
  become the sole authority on money math (VAT, shipping, coupon all
  reimplemented), zero-total orders need a special no-PaymentIntent path, and
  the hosted fallback becomes a second, divergent flow. More work and more
  divergence risk than a parity-only v1 needs.
- **Embedded Checkout (`ui_mode: "embedded"`):** cheapest fix for the
  redirect, but it is Stripe's form in an iframe — afida does not own the
  page, which contradicts the goal.

## Scope

In scope (parity only):

- Full checkout page on afida.com: order summary, email, GB-only shipping
  address, the two shipping options (standard £4.99 / express £9.99), 20% VAT,
  welcome coupon applied server-side by coupon ID.
- Payment methods: cards, Apple Pay / Google Pay, Link.
- Feature flag with instant fallback to hosted Checkout.

Out of scope (later enhancements):

- Editing the cart on the checkout page (summary is read-only; edit links go
  back to the cart).
- On-page promo-code entry, order notes, custom fields, BNPL.
- Any change to order creation, the webhook handler, or the success flow.

## Architecture

The flag lives in one place: `CheckoutsController#create`.

- **Flag off:** exactly today's behaviour — create a hosted session, redirect
  to `session.url`.
- **Flag on:** create the session with `ui_mode: "custom"` and a `return_url`
  (in place of `success_url`/`cancel_url`), then render the checkout page,
  passing the session's `client_secret` to the view.

Both modes share the same session-creation params (line items, tax rates,
GB-only `shipping_address_collection`, `shipping_options`, `discounts:` with
the welcome coupon ID). The flag switches only `ui_mode` and the URL params.

Everything after payment is untouched. Stripe redirects to the same success
URL with `{CHECKOUT_SESSION_ID}`, so `CheckoutsController#success`, the
duplicate-order guard, the webhook handler, zero-total handling, and the
Datafast purchase-goal wiring all keep working with no changes.

On the page, Stripe.js's `initCheckout(clientSecret)` binds to the session. We
render our own order summary, email field, and shipping-method picker;
Stripe's Payment Element (with Address Element in shipping mode) provides the
secure inputs, showing cards, wallets, and Link. The SDK is the client-side
source of truth for totals: shipping-option changes go through its update
method and displayed totals re-render from what it reports, so the page cannot
diverge from what Stripe charges.

One-time setup outside code: register afida.com and the staging domain for
Apple Pay in the Stripe dashboard (sandbox and live).

## Components

Server side (mostly a refactor of what exists):

- **Session params builder** (`CheckoutSessionParams` or a private builder on
  `CheckoutsController`): extracts today's session-creation hash so hosted and
  custom modes share line items, tax rate, shipping options, and coupon logic.
  Mode-specific bits: `ui_mode`, `return_url` vs `success_url`/`cancel_url`.
- **`CheckoutsController#create`:** branches on the flag as above. `#success`
  and the webhook handler are untouched.
- **Flag:** an ENV var (e.g. `ONSITE_CHECKOUT`), read through one helper
  (`onsite_checkout_enabled?`) so flipping back is an env change plus
  redeploy, no code change. If the shop already has a settings pattern, the
  implementation plan uses that instead.

Client side (the new work):

- **Checkout view:** two-column page (order summary + form) in the shop's
  existing layout and styles. Order summary is server-rendered ERB from the
  cart, read-only in v1.
- **One Stimulus controller (`onsite-checkout`):** initializes `initCheckout`
  with the client secret, mounts Payment Element and Address Element into
  targets, renders shipping-option radios from the session, calls SDK update
  methods on email/shipping changes, subscribes to session changes to
  re-render totals, and calls `confirm()` on submit with inline error display.
- Stripe.js stays loaded from Stripe's CDN (required by Stripe; already the
  case today).

No new models, no migrations: orders are still created from the completed
session exactly as now.

## Data flow

Cart page → POST `CheckoutsController#create` → session created
(`ui_mode: "custom"`) → checkout page renders with client secret → shopper
fills email/address, picks shipping, pays → SDK `confirm()` → Stripe redirects
to the existing success URL with the session ID → order created (or the
webhook races it, as today, guarded against duplicates).

## Error handling

- **Payment declined / validation errors:** `confirm()` returns the error;
  the Stimulus controller shows it inline above the pay button and re-enables
  it. Stripe handles 3DS challenges itself.
- **Stale session** (sessions expire after 24h; cart changed in another tab):
  the checkout page is rendered fresh from `#create` on every visit, so each
  visit gets a session matching the current cart. A confirm on an expired
  session surfaces an SDK error; the inline message tells the shopper to
  refresh, which mints a new session.
- **JS fails to load / SDK init error:** the page shows a fallback message
  with a link that re-submits to checkout; if problems persist, flip the flag
  and everyone is back on hosted Checkout.
- **Zero-total orders:** the session completes with `no_payment_required` as
  today; existing gates already accept both statuses.
- **Abandoned checkout:** nothing to clean up; unconfirmed sessions expire,
  same as abandoned hosted sessions today.

## Rollout

Ship behind the flag with hosted Checkout as instant fallback. Verify on
staging (flag on) against Stripe sandbox, then enable in production. Keep the
hosted path wired until the on-site flow has processed real orders without
incident; removing the flag and hosted branch is a later cleanup task.

## Testing

- **Controller tests:** flag off → redirect to Stripe URL (existing tests keep
  passing); flag on → renders the checkout page, session created with
  `ui_mode: "custom"`, correct `return_url`, and identical
  line-item/shipping/coupon params to hosted mode (Stripe API stubbed the same
  way existing checkout tests stub it).
- **Shared params:** unit test that the builder produces the same core hash
  for both modes, so the refactor cannot silently drift the hosted path.
- **Success + webhook:** existing tests already cover order creation from a
  completed session; unchanged, they double as regression cover for the
  fallback path.
- **System test:** flag on, walk to the checkout page and assert our page
  renders with summary, shipping options, and the Stripe mount points present.
  Driving the real Payment Element iframe in CI is flaky by design, so
  confirm-and-pay is covered manually on staging (Stripe test mode) before
  flipping the flag in production.
- **Manual staging checklist:** card, Apple Pay, Link, welcome coupon,
  100%-off coupon (zero total), express shipping, declined card.
