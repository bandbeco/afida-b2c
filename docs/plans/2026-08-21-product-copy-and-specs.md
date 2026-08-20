---
type: Plan
description: Replace formulaic product descriptions with facts, in three sequenced moves; promote fit into the spec table from the curated mappings, fix the spec vocabulary, then cut the prose back to what only prose can say.
status: active
timestamp: 2026-08-21
---

# Product Copy and Specs

Successor work to the [Product Page Buy Box Overhaul](/plans/2026-08-20-pdp-buy-box-overhaul.md), which fixed how the page sells and left the words alone. This is about what the page actually says.

## The problem

Product descriptions read as generated filler. Measured across the 658 active products that have a standard description:

* **84% restate the product title in their first clause.** The title already says "Kraft Paper Double Wall Coffee Cups - 12oz / 340ml"; the description opens "12oz kraft double wall paper coffee cups with built-in insulation." The buyer learns nothing from the first sentence they read.
* **20%** use "perfect/ideal/great for", **16%** end with the identical boilerplate "Designed for coffee shops, cafés, offices, events, and catering", and there is a recurring "[adjective] construction" tic.
* Median length is 28 words, most of it restatement and adjectives ("artisan cafe appeal", "innovative double wall construction", "earthy, eco-friendly appearance").

The three description fields are inversely useful. For the 12oz double wall cup, `description_short` is the only one carrying an actionable fact ("Fits 90mm sip lids"); `description_standard` restates the title; `description_detailed` is the most decorative of the three. Length is being spent on adjectives rather than facts.

Context for how much this matters: product pages are 55% of traffic, and 92% of the product pages in the top 100 made zero sales last month (1,725 visitors, £317 revenue).

## Why not simply delete the prose and show specs

Tempting, and specs do beat this copy on its own terms: "rPET / Clear / 9oz / 255ml / Recyclable" is scannable and comparable in a way the paragraph is not. But two things block a straight swap.

1. **168 descriptions carry fit claims no spec row holds** ("fits 80mm sip lids", "fits 76 Series cup rims", "pairs with compatible Vegware lids"). For a lid or container buyer that is the buying question, and deleting the prose deletes it.
2. **The spec table is not yet strong enough to stand alone.** Before the buy-box work it had a Volume row duplicating the Size row on 65 products and a single-row Dimensions column on 154. The tile grid shipped 2026-08-21 fixed the layout, but the underlying vocabulary is still wrong (see move 2).

Sequencing matters: doing the prose cut first strips 168 fit claims and leaves the thin-spec products with an empty page.

## The three moves

### Move 1: promote fit into the spec table

The curated container-to-lid join already holds this, better than prose does. Production has 432 mappings covering 151 containers and 88 lids, averaging 2.9 lids per mapped container. Against the prose:

* **103 products are mapped but say nothing about fit in their copy.** The data exists and the page never mentions it.
* **32 products claim a fit in prose that no mapping backs.** Unverifiable sentences, and each is either a missing mapping or a wrong claim.

Generating a "Fits" spec row from the join covers 239 products instead of 168, is verifiable, and stays correct as curation changes. It is purely additive, needs no copy decisions, and makes the later prose cut safe. Do this first.

The 32 unbacked claims become a review list: each is a mapping to add or a sentence to correct.

### Move 2: fix the spec vocabulary

The tile grid is right; what it labels is not. Production's `certifications` column is a clean controlled vocabulary of eight tokens:

| Token | Count |
|---|---|
| Compostable | 366 |
| Recyclable | 221 |
| Food Safe | 37 |
| Biodegradable | 22 |
| FSC | 6 |
| Plastic Free | 2 |

(plus lowercase `recyclable` 7 and `compostable` 3, already handled by case folding)

Only **FSC** is a certification anyone awards. "Compostable", "Recyclable", "Biodegradable" and "Plastic Free" are material properties, and "Food Safe" is a compliance claim. The shipped `MATERIAL_PROPERTIES` allow-list currently promotes only "Recyclable", so 366 Compostable products still render it under a "Certified" heading. That is the same credibility problem the recyclable fix was meant to solve, at five times the scale.

A review-flagged concern that this exact-match filter would miss real-world variants ("100% recyclable", "Fully Recyclable") is **not borne out**: the column holds only these eight tokens. Exact matching is sufficient here.

Also worth resolving: some products carry both `length_in_mm` and `height_in_mm` at the same value (the white paper straws render Length 200mm and Height 200mm), which is duplicated data rather than a display fault.

### Move 3: cut the prose back

Only once specs carry the facts. The rule: a description earns its place by saying something the title and the spec table cannot. In practice that is application ("holds a full English without flexing"), a trade-off worth stating, or a genuine incompatibility warning. Everything else goes.

Expect most descriptions to end up shorter than they are now, and some to be dropped entirely where they have nothing left to say.

## Risks and how to handle them

* **SEO.** Descriptions are indexed content, and the [2026-08-18 audit](/seo/seo-audit-2026-08-18.md) found position, not CTR, is the binding constraint on this site. A bulk rewrite is a live risk. Hold out a control group rather than rewriting everything at once, and judge at the next GSC checkpoint rather than assuming an improvement.
* **Scale.** 658 products is not a hand-editing job. This shop already has a proven pattern for bulk-rewriting a product field: a rake task driving the Anthropic API (the key lives in the shared credentials vault), writing a CSV for review, applied only after that review over `kamal app exec`. Reuse it. The CSV review step is what keeps a bulk rewrite honest, and it is not optional.
* **Ordering.** Moves 1 and 2 are additive and reversible. Move 3 is the destructive one and must come last.

## Success signals

Add-to-cart rate on product pages, and specifically on the 239 mapped products where fit reassurance is newly visible. Sample-request volume is the counter-signal to watch: samples are the engaged-lead unit of the B2B funnel, so if better copy reduces sample requests that is worth knowing rather than celebrating.

## Out of scope

* Rewriting product **titles**, which are generated and carry SEO weight of their own.
* The missing physical dimensions (`diameter_in_mm` is populated on 20 of 666 products, `weight_in_g` on 208). A catalogue data-entry job, not a copy job.
* Category and collection page copy.
