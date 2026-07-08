---
type: Runbook
description: Stripe Checkout gotchas that have bitten before; zero-total payment status, line_items pagination, and how the welcome coupon is applied.
status: active
timestamp: 2026-07-08
---

# Stripe Checkout Gotchas

## Zero-total orders

Orders discounted to £0 (e.g. a 100%-off coupon) complete with `payment_status: "no_payment_required"`, not `"paid"`. Every gate that decides whether an order is complete must accept BOTH values, in the checkout flow and in the webhook handler (`app/controllers/webhooks/stripe_controller.rb`).

## line_items pagination

`Stripe::Checkout::Session.retrieve` paginates `line_items` at 10. Any logic that rebuilds an order from the session must paginate, and the shipping line must be prepended to the list, not assumed to be within the first page.

## Welcome coupon

The welcome 10%-off is a WHOLE-ORDER coupon (subtotal plus shipping). The app applies it by Stripe COUPON ID from `credentials.stripe.welcome_coupon` (different IDs in sandbox and live), NOT by the promo-code string "WELCOME10"; that literal is unusable as a coupon id. Preview math in `OrderTotals` must mirror Stripe's whole-order discount behaviour or the preview and the charge diverge.
