---
type: Plan
description: Consolidated implementation checklist for the three Hormozi trilogy proposals (Money Model, Grand Slam Offer, Leads), merging their interlocking build orders into four phases with per-item ownership and the shared scoreboard.
status: active
timestamp: 2026-08-17
---

# Hormozi Trilogy Implementation Plan

Execution tracker for the August 2026 trilogy: the [Money Model Proposal](/proposals/money-model-2026-08.md) (what happens after the first purchase), the [Grand Slam Offer Proposal](/proposals/grand-slam-offer-2026-08.md) (what the first offer is), and the [Leads Proposal](/proposals/leads-2026-08.md) (how strangers find out it exists). Each proposal ends with a build-order section that references the others; this doc merges those three orders into one phased checklist so progress is trackable in a single place. The proposals stay the source of rationale; when a play's scope is unclear, read the play there.

Ownership follows the Leads proposal's split: channel motions (messages, partner conversations, quote negotiations) belong to Afida leadership; code and email-flow work belongs to the dev retainer. Items are tagged accordingly.

## Groundwork already done

* [x] Reorder-schedule expiry dead-end fixed so schedules renew instead of silently dying (master `1d8c0d58`).
* [x] Zombie reorder schedule repaired in production (2026-08-17).

## Phase 1: now

The confirmation page is the shared surface: the continuity bonus card and the referral ask ship as one combined change.

* [ ] **Continuity bonus on the order confirmation page** (Money Model play 1, dev). Replace the empty "Set Up Reorder Schedule" card with a real offer: set up a scheduled reorder now and delivery on today's order is free (or a free sleeve of lids).
* [ ] **Referral ask beside the continuity card** (Leads play 2, dev). Two-sided, product-denominated: give a free sleeve of lids, get a free sleeve of lids. Same confirmation-page change as the item above.
* [ ] **Run-out-timed Klaviyo re-offer** (Money Model play 1, dev). Estimate consumption from pack size and quantity; email at roughly 80% of predicted run-out with the tick-and-never-run-out schedule offer at 5% off.
* [ ] **Referral ask in the post-delivery Klaviyo email** (Leads play 2, dev). Same two-sided offer as the confirmation card.
* [ ] **Denominator copy on category pages and the sample funnel** (Grand Slam play 2, dev). Lead with "order by 2pm, on your counter tomorrow, lids guaranteed to fit" instead of product specs.
* [ ] **Named guarantees on product pages and checkout** (Grand Slam play 3, dev). Name and place the fit-and-quality guarantee and the never-run-out promise (the latter attached to scheduled reorders).
* [ ] **Warm outreach over the trade book and lapsed buyers** (Leads play 1, Afida leadership). Fixed daily count of personal messages with the sample box or rollover as the give and the referral question as the ask. No code; can start immediately.

## Phase 2: next

* [ ] **Cart-level compatible-lids upsell** (Money Model play 2, dev). Surface the lids prompt in the cart, not only on product pages.
* [ ] **Free-delivery nudge in the cart** (Money Model play 2, dev). AOV £96 against the £100 threshold: "add £4 for free delivery" line.
* [ ] **Welcome offer reframed as free product** (Money Model play 2, dev). Test "free sleeve of lids with your first cup order" or free delivery against the 10% coupon at the same margin cost.
* [ ] **Quantity tiers rendered as "buy 4 cases, get 1 free"** (Money Model play 2, dev). Same maths as the existing `pricing_tiers` per-unit break, better story.
* [ ] **MAGIC naming pass over the sample flow and welcome offer** (Grand Slam play 5, dev). "Free samples" becomes "Free Café Packaging Starter Kit (choose 6, delivered tomorrow)"; the reframed welcome offer gets a name; batched with the reframes above.

## Phase 3: then

Centred on merging the `lead-monitor` branch with the new-opening kit as its reason to exist.

* [ ] **New-opening Grand Slam Offer kit** (Grand Slam play 1, dev + Afida leadership). Run the five steps for the new-food-business avatar; build the stack assets: quantity-prescription templates per business type, curated sample box, next-day top-up promise copy, UK packaging-compliance one-pager, first-scheduled-reorder bonus.
* [ ] **Merge the `lead-monitor` branch** (dev). The kit is the attraction offer that justifies the merge.
* [ ] **Cold-outreach last mile on the lead monitor** (Leads play 3, dev for the layer, Afida leadership for the motion). Contact fields, message templates, sent/replied tracking on Lead records; personalised messages leading with the free kit, follow-ups day 1/2/7, list re-run after 3 to 6 months.
* [ ] **Sample-to-prescription follow-up** (Money Model play 3, dev). After samples ship: prescription email, then the A/B close (one-off order or monthly delivery), wired to the lead monitor for new openings.
* [ ] **Avatar offer pages in the next SEO batch** (Grand Slam play 4, dev). /for/coffee-shops, /for/street-food and so on: named bundle, prescription, guarantee, sample-box CTA. Bridges the [B2B organic plan](/seo/b2b-organic-growth-plan-2026-07.md) and the money model.
* [ ] **"How [a real café] switched" case-study content** (Leads play 5, dev + Afida leadership). Folded into the next content batch; doubles as testimonial ammunition for the other plays.
* [ ] **Engaged-lead counting** (Leads measurement, dev). Sample requests plus outreach replies per week, split by channel.
* [ ] **Rollover win-back for the 86 lapsed one-time buyers** (Money Model play 5, dev + Afida leadership). Credit the last delivery fee toward the first scheduled reorder; new offer at least 4× the credit.

## Phase 4: gated

* [ ] **Partner white-label pilot** (Leads play 4, Afida leadership). 3 to 5 partners from existing relationships; giveables are the compliance one-pager (white-labelled) and the sample box; pay in product. Gated on the kit and one-pager existing.
* [ ] **Partner bonuses inside the new-opening kit** (Grand Slam play 6 second half, Afida leadership). Roaster or POS partner offers as zero-cost bonuses; only if the kit works.
* [ ] **Scale paid ads** (Money Model build order step 4, Leads play 6, dev + Afida leadership). Gated on repeat purchase demonstrably working, LTGP:CAC at least 3:1, and 30-day cash covering CAC. When opened, use the operating system from the Leads proposal (avatar call-outs, matching landing pages, one test per week, kill rules at 2× 30-day cash) and the [Google Ads campaign structure](/proposals/implementation/03-google-ads-campaign-structure.md).

## Deliberately not planned

Per each proposal's "what to ignore" section: card-on-file penalty trials, payment-plan waterfalls and gasp-and-rescue scripts (Money Model); countdown timers, cohort caps and fake scarcity (Grand Slam Offer; the only honest scarcity is batch-limited own-brand import runs); 100-per-day outreach volume prescriptions and the employees/agencies chapters (Leads). Anchor Upsell via the branded configurator (Money Model play 4) and cart/quote downsells (play 6) are in the proposals but unscheduled; pull them into a phase when the earlier plays prove out.

## Scoreboard

Pull monthly, alongside the ~2026-08-16 SEO measurement cadence:

* Repeat-purchase distribution: active reorder schedules, share of customers with 2+ orders in 180 days, revenue from scheduled reorders (baseline 2026-08-09: 86 of 99 customers bought exactly once, 1 active schedule).
* Engaged leads per week (sample requests + outreach replies), split by channel.
* Referral rate vs lapse rate (compounding when referrals exceed lapse).
* Sample-request rate, sample-to-first-order conversion, first-order AOV.
* LTGP:CAC, which must clear 3:1 before any ad budget rises.
