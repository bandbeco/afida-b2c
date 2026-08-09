---
type: Proposal
description: Apply Hormozi's "$100M Money Models" offer-sequence framework to afida.com; diagnosis is a working attraction layer feeding a missing back end, so the plays prioritise continuity (scheduled reorders), free-framed offers, and sample-to-prescription follow-up.
status: active
timestamp: 2026-08-09
---

# Money Model Proposal (August 2026)

**Source framework:** Alex Hormozi, *$100M Money Models* (2025).
**Prepared:** 2026-08-09, from a full read of the book plus production data pulled the same day.
**Companion:** the [Grand Slam Offer Proposal](/proposals/grand-slam-offer-2026-08.md) applies the earlier *$100M Offers* book to the front end (the first offer a prospect sees); the [Leads Proposal](/proposals/leads-2026-08.md) applies *$100M Leads* to how strangers find the offer; this document covers the sequence after the first purchase.

## The framework in one paragraph

Hormozi's claim is that a business grows as fast as its "money model": a deliberate sequence of offers (Attraction, then Upsell, then Downsell, then Continuity) engineered so that gross profit from a new customer covers the cost of acquiring and serving them within 30 days. Once that holds, advertising funds itself and cash stops being the growth constraint. His build order is explicit: get one attraction offer working, add an upsell, add a downsell for the "no"s, add continuity, and perfect one stage at a time.

## Where Afida stands (production data, 2026-08-09)

Last 180 days of paid online orders:

| Metric | Value |
| --- | --- |
| Paid orders | 120 |
| AOV | £96 |
| Customers who bought exactly once | 86 of 99 |
| Bought 2× / 3× / 4× | 7 / 4 / 2 |
| Active reorder schedules | 1 |

Mapped onto the four offer stages, the striking thing is that Afida already owns most of the machinery the book prescribes, but the model ends at the first purchase:

| Stage | Afida today |
| --- | --- |
| Attraction | Free samples (customer pays delivery), 10% welcome coupon, SEO/blog CTAs (see [B2B organic plan](/seo/b2b-organic-growth-plan-2026-07.md)) |
| Upsell | Compatible-lids cross-sell on product pages, quantity pricing tiers, branded-packaging configurator, £100 free-shipping threshold |
| Downsell | Nothing |
| Continuity | Reorder schedules fully built (off-session Stripe billing, pause/resume, four frequencies); one active schedule in production |

Cups, lids and napkins are consumables. A café that ordered once ran out weeks ago and is now buying elsewhere. In the book's terms this is a working attraction layer feeding a missing back end. It is also why paid traffic has never been safe to scale: at one £96 order per customer almost no CAC pays back in 30 days; with a working reorder motion, it can.

## The plays, in priority order

### 1. Make continuity the default outcome of every first order (biggest lever)

The book's rule: nobody signs up for unproven recurring billing cold, so you buy the signup with a bonus or discount. Its dog-food example (bulk first order, automatic renewal, bonuses for staying) is the template for a consumables shop.

* **Continuity bonus at purchase.** The confirmation page currently shows a plain "Set Up Reorder Schedule" card with nothing in it for the customer; that is a membership pitch, not an offer. Replace with: "Set up a scheduled reorder now and delivery on today's order is free" (or a free sleeve of lids).
* **Timed re-offer at the run-out date.** Pack sizes and quantities are known, so consumption can be estimated. A Klaviyo email at roughly 80% of predicted run-out ("time to top up; tick this box and never run out again, 5% off every scheduled delivery") makes the offer at the moment the next problem appears, which is the book's core timing rule.
* **Lifetime discount past the churn point.** After the third scheduled delivery, lock in a permanently better rate. The book presents this timed loyalty discount as the cheapest churn killer available.
* **Sizing.** Moving 20 of the 86 one-time buyers onto a monthly £96 reorder is roughly £11-12k incremental annual revenue, on the order of 2× the current online run rate.

### 2. Reframe existing discounts as free stuff

"Buy X get Y free" outsells a mathematically identical percentage discount, and both levers are already priced in:

* **Welcome offer.** Test "free sleeve of lids with your first cup order" (or free delivery) against the 10% coupon. Same margin cost, stronger pull, and it does not train trade buyers to expect blanket discounts.
* **Quantity tiers.** Render existing `pricing_tiers` as "buy 4 cases, get 1 free" instead of a per-unit price break. Identical maths, better story.
* **Free-shipping nudge.** AOV is £96 against a £100 threshold. Add a cart line ("add £4 for free delivery") and surface the compatible-lids prompt in the cart, not only on product pages.

### 3. Turn samples into a Menu Upsell funnel

Samples are the natural attraction offer for this business but currently a dead end. The book's Menu Upsell sequence (unsell, prescribe, A/B choice, low-friction close) maps directly: after samples ship, follow up with a prescription ("for a café your size: 2 cases of 8oz cups, 1 case of lids"), then an A/B close that assumes purchase ("one-off order, or monthly delivery?").

This is also the monetisation story for the lead monitor (unmerged `lead-monitor` branch): a newly registered food business is the book's "hyper buying cycle" (buying everything at once, this month, and whoever gets them first keeps the reorders). A free sample box offered to new openings is the attraction offer that pipeline was missing.

### 4. Use the branded configurator as an Anchor Upsell

Present custom-branded packaging first on category pages at its real price; plain stock then reads as the sensible deal, and occasional branded sales are high margin and feed the own-brand direction Afida leadership wants anyway. The anchor must be genuinely buyable, never a prop.

### 5. Win back lapsed buyers with a rollover, not a discount

The 86 lapsed one-time buyers are the cheapest revenue available. The Rollover Upsell credits something from the past purchase toward a bigger next step: "we'll credit your last delivery fee toward your first scheduled reorder", positioned personally. Rule of thumb from the book: the new offer should be at least 4× the credit, capping the effective discount at 25%.

### 6. Downsells for the quiet "no"s

For abandoned carts and stalled branded-packaging quotes, never discount the same thing (the book's hardest rule: same thing for less money erodes trust and price integrity). Change what they get instead: a smaller starter bundle for cart abandoners; plain stock now with branded later for stalled quotes.

## What to ignore from the book

Card-on-file penalty trials, seven-step payment-plan waterfalls, and gasp-and-rescue sales scripts are built for high-ticket services sold on calls. Forcing them into a self-serve £96-AOV shop would damage the trade-buyer relationship. The transferable spine: free beats discount, upsell at the moment the next problem appears, never discount without trading for commitment, and get consumable buyers onto scheduled delivery.

## Build order

1. **Now:** continuity bonus on the confirmation page plus the run-out-timed Klaviyo re-offer. The machinery exists; this is mostly copy and one email flow.
2. **Next:** cart-level lids upsell, free-delivery nudge, "get Y free" reframes of the welcome offer and tiers.
3. **Then:** sample-to-prescription follow-up, wired to the lead monitor for new openings.
4. **Only after repeat purchase demonstrably works:** scale paid traffic (see [Google Ads campaign structure](/proposals/implementation/03-google-ads-campaign-structure.md)), because at that point CAC finally has a payback story.

## Measurement

The scoreboard is the repeat-purchase distribution above: active reorder schedules, share of customers with 2+ orders in 180 days, and revenue from scheduled reorders. Re-pull those three numbers monthly; the plays are working if the 86-of-99 one-time share falls and schedule count climbs past single digits.
