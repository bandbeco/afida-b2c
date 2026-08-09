---
type: Proposal
description: Apply Hormozi's "$100M Offers" framework to afida.com's front end; the shop sells commodities presented as commodities, so the plays compose existing assets (next-day delivery, samples, compatible-lids data, guarantees-in-behaviour) into named, incomparable offers, starting with a Grand Slam Offer for new food-business openings.
status: active
timestamp: 2026-08-09
---

# Grand Slam Offer Proposal (August 2026)

**Source framework:** Alex Hormozi, *$100M Offers* (2021).
**Prepared:** 2026-08-09, from a full read of the book.
**Companion to:** the [Money Model Proposal](/proposals/money-model-2026-08.md). That document applies the *sequencing* book (what to offer after the first purchase: continuity, upsells, downsells). This one applies the earlier book to the first offer itself: what a prospect sees before they have ever bought.

## The framework in one paragraph

Hormozi's claim is that a commodity gets bought on price while a differentiated offer gets bought on value, and that the fix is never a lower price but a "Grand Slam Offer": a bundle so tailored to one avatar's problems that it cannot be compared to anything else on the market. The recipe: pick a starving-crowd market (growing, in pain, easy to target, able to pay), enumerate the avatar's dream outcome and every problem in the way, turn each problem into a stack item, then enhance the bundle with a named guarantee, honest scarcity and urgency, bonuses instead of discounts, and a name built from his MAGIC formula (reason why, avatar, goal, interval, container). Value itself is a fraction: (dream outcome × perceived likelihood of achievement) over (time delay × effort and sacrifice), and the strongest competitors win on the denominator: faster and easier, not bigger promises.

## The diagnosis the book forces

Afida is a textbook commodity seller. A Vegware 8oz cup on afida.com is the same cup Nisbets and every other distributor sells, presented the same way: SKU, unit price, add to cart. Every value lever Afida actually has already exists in the codebase but is not composed into an offer:

| Asset | Where it lives today | What the book says it is |
| --- | --- | --- |
| Next-working-day delivery, 2pm cutoff | `DeliveryEstimate`, shown as a delivery detail | The time-delay weapon ("fast beats free") |
| Free samples (customer pays delivery) | Sample flow | A zero-risk trial, i.e. an unnamed guarantee |
| Compatible-lids data | Product-page cross-sell | The effort-and-sacrifice killer ("will the lid fit?") |
| Branded-packaging configurator | Standalone feature | A price anchor |
| Quantity tiers, £100 free shipping | Pricing machinery | Raw material for stacked bonuses |

Nothing here needs building. The work is composition, naming, and copy.

## The plays, in priority order

### 1. Build one Grand Slam Offer for one avatar: the new food-business opening

The book's hierarchy is market > offer > persuasion, and its ideal market is a starving crowd. Afida has already found one: the lead monitor (unmerged `lead-monitor` branch) identifies newly registered food businesses, which the [Money Model Proposal](/proposals/money-model-2026-08.md) calls a hyper-buying cycle. What is missing is the offer to put in front of them.

Run the book's five steps (dream outcome → problem list → solutions → delivery vehicles → trim and stack) for exactly this avatar. Their dream outcome is not "buy cups"; it is "opening day goes smoothly and my packaging makes my brand look good". Their problems, each of which becomes a stack item:

| Problem | Stack item | Cost to Afida |
| --- | --- | --- |
| Don't know what sizes or quantities to order | Written quantity prescription ("for a 30-cover café: 2 cases 8oz, 1 case lids...") | One template per business type, reused forever |
| Can't judge quality from a photo | Free curated sample box for their business type | Existing sample flow, curated |
| Terrified of running out mid-week | Next-day top-up promise: order small, never run out | Already true, just unsaid |
| Worried eco claims won't hold up | Plain-English UK packaging-compliance one-pager | One asset, reused forever |
| Cash-poor at opening | First-scheduled-reorder bonus (ties into money-model play 1) | Priced into the continuity offer |

Most of these are the book's "create once, deliver forever" assets: high one-time effort, near-zero marginal cost. Stacked and named, they are incomparable to a distributor's product grid. This is also the attraction offer that finally gives the lead-monitor branch a reason to merge.

### 2. Sell the bottom of the value equation: speed and effort

Value = (dream outcome × perceived likelihood) ÷ (time delay × effort). Hormozi argues the best companies compete on the denominator, and that "fast beats free". Afida's next-working-day, 2pm-cutoff promise is a genuine denominator weapon against large distributors, and today it is a delivery detail rather than the headline. Same for effort: "which lid fits this cup" is a real buyer anxiety the compatible-lids data already solves. The change is nearly free: category pages and the sample funnel should lead with "order by 2pm, on your counter tomorrow, lids guaranteed to fit" rather than product specs.

### 3. Name a guarantee instead of merely having good behaviour

Risk is the biggest objection, and an unnamed guarantee does no selling work. Two fit a consumables shop:

* **Fit-and-quality guarantee.** "If the lids don't fit or your customers don't love the cups, we replace the case or refund it." Free samples make this nearly zero-cost to honour (buyers who sampled rarely mis-order), and the book's refund maths says the conversion lift dwarfs the claims: a guarantee only loses money if the absolute refund increase exceeds the absolute sales increase, which almost never happens.
* **Never-run-out promise** attached to scheduled reorders, strengthening money-model play 1.

Both need a memorable name and placement on the product page and in checkout.

### 4. Niche the storefront messaging by avatar, not by product category

"Riches in the niches": the same product renamed for a narrower avatar commands more attention and price. GSC already proves this for Afida ("sustainable packaging for restaurants" at position 2.76 is the best-performing B2B page; see the [B2B organic plan](/seo/b2b-organic-growth-plan-2026-07.md)). The SEO plan treats those as landing pages; this book upgrades them to offer pages: /for/coffee-shops, /for/street-food and so on, each presenting the same catalogue as a named bundle with the avatar's problems solved ("The Coffee Shop Switch Kit"), a prescription, the guarantee, and the sample-box CTA. This is the bridge between the SEO work and the money model.

### 5. Use the MAGIC naming formula on every offer that already exists

Reason why + avatar + goal + interval + container. "Free samples" becomes "Free Café Packaging Starter Kit (choose 6, delivered tomorrow)". The welcome discount, once reframed as free product per the money-model proposal, gets a name too. When a promo fatigues, change the wrapper (name, season) rather than the economics: the same offer can run year-round as the "Spring menu refresh kit", the "Winter cup stock-up", and so on, which suits Klaviyo campaigns well.

### 6. Bonuses and price anchoring, not discounts

This reinforces the money-model proposal (free beats discount, never discount the core offer) and adds two tools. First, present bundles as an itemised stack with a value on each line so the price-to-value gap is visible. Second, use the branded-packaging configurator as the visible anchor so plain stock reads as the sensible deal. The book also suggests other people's products as zero-cost bonuses; for Afida that could be a partner offer (a coffee-roaster or POS discount inside the new-opening kit), worth exploring only after the kit itself works.

## What to ignore from the book

Countdown timers, cohort caps and "only 3 spots left" theatrics are built for info products and would corrode trust with trade buyers. The only honest scarcity Afida has is genuinely batch-limited own-brand import runs (straws today, more SKUs if the own-brand direction advances), where "this container's stock" framing is real and usable. Likewise the extreme premium-pricing chapters: Afida cannot 5x commodity cup prices, but it can stop competing on unit price by selling named bundles where comparison is impossible, which is the same lesson at trade-appropriate scale.

## How this slots into the money-model build order

The [Money Model Proposal](/proposals/money-model-2026-08.md)'s build order stays intact (continuity bonus first). This proposal's contribution is the front end:

1. **Alongside the confirmation-page work:** plays 2 and 3 (denominator copy, named guarantees) are copy-level changes.
2. **Next:** play 5 naming pass over the sample flow and welcome offer, folded into the same batch as the money-model "get Y free" reframes.
3. **Then:** play 1, the new-opening Grand Slam Offer, shipped with the lead monitor; play 4 avatar offer pages folded into the next SEO batch.
4. **Later, only if the kit works:** partner bonuses (play 6, second half).

## Measurement

Extends the money-model scoreboard toward the front of the funnel: sample-request rate, sample-to-first-order conversion, and first-order AOV, alongside the repeat-purchase distribution. For play 4, GSC clicks and position on the avatar offer pages against the existing category baseline at the ~2026-08-16 measurement pull.
