# SEO Backlog

**Last reviewed:** 2026-05-12 (re-prioritised after fresh GSC pull, same day)
**Owner:** Laurent
**Cadence:** Re-prioritise after each 4-week GSC measurement.

This is the working list of *open* SEO work, grounded in repo state, GSC data, and existing strategy docs. It is intentionally short: items move off when they ship or when measurement shows they aren't worth the effort.

It is **not** a roadmap of everything that could be done. Items belong here only when there is (a) evidence the work matters, and (b) a clear next action. Speculative ideas live in `docs/seo/ideas.md` (create when needed) or as draft GitHub issues, not here.

---

## What's already shipped (do not re-propose)

- **Programmatic SEO foundation** (PR #82, #75, #85): structured data, sitemap, robots.txt, canonical URLs, JSON-LD on products / categories / collections, per-page meta titles and descriptions. See `docs/plans/2025-11-06-comprehensive-seo-implementation.md` (Tasks 1–24).
- **Category buying guides**: all 32 product categories have a `buying_guide` populated. Issue #106 is closed; the rollout is complete.
- **Collection buying guides shipped**: `/collections/vegware`, `/collections/restaurants`, `/collections/coffee-shops`. PRs #171, #172, #173.
- **Product meta_description rewrite**: 672/672 products now use generator-built descriptions (107–155 chars, 0 echoes of full title). See `lib/tasks/rewrite_product_descriptions.rake` and `~/.claude/.../reference_llm_catalog_rewrite_pattern.md`.
- **Blog content**: 40 posts published, 31 drafts (most are Outrank auto-imports — see audit below).

---

## Active backlog

### B0. Meta-title CTR rewrite on top 5 impressions-no-clicks blog pages

**What:** Hand-rewrite the meta title + description on the 5 blog pages collectively eating ~32,000 impressions / 90d at ~0.25% CTR.

**Why:** Highest-leverage move on the site right now. Impressions are 8× since February but clicks are flat — almost all the new traffic is landing on informational blog posts that don't satisfy commercial intent. These 5 pages average position 7 but 0.06–0.43% CTR (normal pos-7 CTR is 3–5%). Lifting CTR to even 1% would add ~240 clicks / 90d, which **roughly doubles total site clicks** with no ranking improvement needed.

**Target pages (90-day data to 2026-05-12):**

| Page | Imp | Clicks | CTR | Pos |
|---|---:|---:|---:|---:|
| `/blog/startup-costs-for-coffee-shop` | 12,255 | 32 | 0.26% | 6.8 |
| `/blog/smoothie-cups` | 6,898 | 30 | 0.43% | 5.9 |
| `/blog/how-to-start-a-catering-business` | 5,045 | 3 | 0.06% | 8.3 |
| `/blog/paper-napkins` | 4,272 | 7 | 0.16% | 6.8 |
| `/blog/can-you-recycle-pizza-boxes` | 3,532 | 7 | 0.20% | 8.9 |

**Approach:**
- `startup-costs-for-coffee-shop` and `how-to-start-a-catering-business` rank for "how do I start a..." queries — pure informational, mostly wrong-fit for a packaging supplier. Pivot the meta toward the **packaging-supplies-needed-to-open** angle so the small fraction of searchers thinking about supplies converts.
- `smoothie-cups` ranks for "best cups for smoothies" (consumer Yeti-tier intent). Surface the **commercial / for-cafes / bulk** angle earlier than the informational angle.
- `paper-napkins` and `can-you-recycle-pizza-boxes` are closer to right-fit — just need stronger CTR-hooks in the title.

**Next action:** Draft 5 title+meta pairs, ship as one PR, measure at the 2026-06-08 GSC pull.

**Source:** GSC analysis 2026-05-12 (see end of this doc).

---

### B0b. Internal-link audit: blog ↔ collections

**What:** Add reciprocal internal links between the 5 high-impression blog posts and the matching `/collections/*` page (and matching `/categories/*` page where relevant).

**Why:** The high-impression blog pages currently orphan their traffic — they pull in informational searchers but don't funnel them to commercial pages. Conversely, `/collections/*` pages don't currently link to blog content that maps to their audience. Two-way linking turns the blog impression pile-on into commercial sessions and gives the collections pages topical authority signals.

**Specific links to add:**

- `/collections/coffee-shops` → `/blog/startup-costs-for-coffee-shop`, `/blog/how-to-start-coffee-shop`, `/blog/takeaway-coffee-cups`
- `/collections/restaurants` → `/blog/how-to-start-a-catering-business`, `/blog/sustainable-food-packaging`
- `/collections/ice-cream-parlours` → `/blog/paper-ice-cream-cups-sizes-materials-buying-guide`, `/blog/milkshake-cups`
- Each of the 5 B0 blog posts → end with a "Shop the [category]" CTA pointing to the relevant `/collections/*` or `/categories/*` page (not a generic `/shop` link).

**Next action:** Audit outgoing internal links on the 5 B0 pages. Patch where the commercial-page link is missing or generic.

**Source:** GSC analysis 2026-05-12.

---

### B0c. Study and replicate the high-CTR pattern

**What:** SERP-inspect the 3 blog pages punching above their position, write up what's working, apply to 5–10 sibling posts.

**Why:** A handful of blog pages are getting 3–5× the average blog CTR at similar positions:

| Page | Imp | Clicks | CTR | Pos |
|---|---:|---:|---:|---:|
| `/blog/paper-bag-for-food` | 59 | 2 | 3.39% | 11.2 |
| `/blog/buy-custom-printed-coffee-cups-small-orders` | 234 | 3 | 1.28% | 9.3 |
| `/blog/vegware-practical-guide-uk-food-business` | 179 | 2 | 1.12% | 8.8 |
| `/blog/takeaway-boxes` | 645 | 6 | 0.93% | 8.0 |

Shared pattern: URLs/topics imply commercial intent (`buy-`, `wholesale`, `practical-guide`, plain product noun) rather than informational ("how to start a...").

**Sibling posts at similar positions but 0.2–0.6% CTR** that could benefit: `/blog/disposable-coffee-cups`, `/blog/paper-coffee-cups`, `/blog/soup-containers`, `/blog/wooden-cutlery`, `/blog/eco-straws`, `/blog/milkshake-cups`, `/blog/pizza-boxes-wholesale`.

**Next action:** Pull each of the 4 high-CTR pages up in a SERP preview (Google search the slug; check title, meta, rich snippet). Write the pattern down in one paragraph. Rewrite the siblings to match. Ship as one PR.

**Source:** GSC analysis 2026-05-12.

---

### B1. Measure impact of recent SEO pushes (due 2026-06-08) — now a decision point

**What:** Re-pull GSC snapshot for `/collections/*`, top product pages, and recently re-titled blog posts. Compare positions and impressions vs the 2026-05-12 reading below.

**Why (updated 2026-05-12):** Fresh GSC pull shows the buying-guide rollout (PRs #171–#173) has **not yet moved clicks** on the target collections at week 2–3: `/collections/restaurants` 250 imp / 0 clicks, `/collections/coffee-shops` 97 imp / 0 clicks, `/collections/vegware/cups-and-drinks` 227 imp / 0 clicks. Positions are within ±0.5 of the 2026-05-10 baseline. The 2026-06-08 pull is now a **stop-or-continue decision point on B2**, not just a measurement.

**Decision rule:**
- If `/collections/restaurants` or `/collections/coffee-shops` gained ≥1 click and ≥3 positions, the buying-guide pattern is working slowly — continue to B2.
- If still 0 clicks and flat positions at week 4, **do not ship more buying guides**. The work moves to B0 / B0b / B0c (which is leverage on existing impression volume, not new content), or to B6 (linkable tool, a different bet entirely).

**Source:** memory `project_seo_week4_measurement_due.md`, `project_seo_collection_rankings_2026_05.md`, GSC analysis 2026-05-12.

---

### B2. Buying guides for remaining business-type collections

**What:** Add a `buying_guide` to the 6 business-type collections that don't have one yet, in priority order.

**Why:** The 3 collections with guides (vegware, restaurants, coffee-shops) cover the highest-impression Tier 2 targets. The remaining business-type collections are either lower-impression or further from page 1, so this is contingent on B1 showing the pattern works.

**Priority (by GSC position × impressions, May 2026):**

| Collection | Position | Impressions/90d | Status |
|---|---:|---:|---|
| `/collections/bakeries` | 7.3 | 27 | Closest to page 1, but tiny impression base |
| `/collections/eco-essentials` | 11.6 | 57 | Page-1-adjacent |
| `/collections/ice-cream-parlours` | 12.1 | 81 | Page 2 |
| `/collections/pubs-bars` | 14.3 | 19 | Page 2 |
| `/collections/hotels` | 15.0 | 24 | Page 2 |
| `/collections/smoothie-juice-bars` | 25.3 | 53 | Page 3 — defer |
| `/collections/takeaway` | 31.2 | 202 | Page 3 — defer; see B5 |

**Next action:** Gate on B1 (now a stop/continue decision point — see B1 above). Provisional read at week 2–3: zero clicks on the shipped buying guides, so the prior is *don't ship more buying guides* unless the 2026-06-08 pull contradicts. If continuing, do `eco-essentials` next (page-1-adjacent + decent impression base). `bakeries` is closer but the impression base is too small to validate impact.

**Skip:** `bakery`, `coffee-shop`, `restaurant`, `smoothie-bar`, `takeaway` (singular slugs — these look like duplicates or legacy redirects, confirm before writing).

**Source:** memory `project_seo_collection_rankings_2026_05.md`, issue #106 (closed) for the buying-guide pattern.

---

### B3. Audit and triage 31 draft blog posts

**What:** Walk the draft list, decide for each: publish, rewrite, or delete.

**Why:** Several drafts are obvious Outrank auto-imports with off-brand topics (`speed-rails-bar`, `kitchen-stainless-shelf`, `staff-only-signage`, `portable-handwash-stations`). Others are duplicates of published posts (`disposable-coffee-cups-2`, `compostable-cups-2`, `ice-cream-cups`, `paper-cups`). A few look genuinely on-brand (`cake-packaging-box`, `cup-carriers`, `dome-lids`, `wholesale-cake-boxes`).

**Risk of doing nothing:** Drafts don't hurt rankings, but they accumulate. The duplicates (`-2` suffix) suggest Outrank may re-import the same topic; need to either configure Outrank to dedupe or set a manual review gate.

**Next action:** One pass through the 31 drafts. Quick rubric: keep if (a) topic maps to an existing product/category and (b) doesn't duplicate a published post. Delete the rest.

**Source:** prod `BlogPost.where(published: false)`.

---

### B4. Outrank workflow review

**What:** Decide whether to keep Outrank auto-publishing blog content, change its config, or kill it.

**Why:** Half of the 31 drafts are off-brand or duplicate. The 40 published posts include some genuinely good ones (`compostable-vs-biodegradable`, `eco-friendly-takeaway-containers`) and several that look auto-generated and never got a meta-title rewrite pass.

**Open questions:**
- What's the monthly Outrank spend vs the value of on-brand posts that come out of it?
- Can Outrank be configured to require human approval before publish?
- Is the meta-title rewrite pass (commits 8625112b, 1fd301c6, 205efc75, etc.) being applied to new Outrank posts as they ship, or only retroactively?

**Next action:** Pull Outrank invoice, count on-brand publishes per £, decide.

**Source:** `docs/seo/outrank-article-instructions.md`, `docs/plans/outrank-webhook-integration.md`.

---

### B5. `/collections/takeaway` — diagnose, don't add content

**What:** Investigate why takeaway sits at position 31 with 202 impressions/90d despite being a flagship category.

**Why:** The original SEO plan named takeaway as the Tier 2 flagship. GSC data contradicts that — it's a Tier 3 page in practice. Pos 31 means content tweaks won't fix it; the page is being out-ranked by something structural (query intent mismatch, weaker internal linking, or a competitor with much deeper topical authority).

**Hypotheses to check:**
- Does the page rank for the *wrong* queries (informational instead of commercial)?
- How many internal links point to `/collections/takeaway` vs `/collections/restaurants`?
- What does the top-10 SERP for "takeaway packaging" look like — what content/format is winning?

**Next action:** Pull GSC top queries for the page, count internal links, eyeball the SERP. Output: a one-paragraph diagnosis. Don't write a buying guide for this page until the diagnosis is in.

**Source:** memory `project_seo_collection_rankings_2026_05.md`.

---

### B6. Linkable asset: "Greenwash or Not?" tool

**What:** Build the interactive greenwashing identifier tool spec'd in `docs/plans/2025-12-24-greenwash-or-not-design.md`.

**Why:** Per `docs/insights/2025-12-24-seo-tools-research.md`, blog content earns near-zero backlinks in the eco-packaging space (EcoEnclose's entire blog: 189 referring domains; individual posts: 1–2 links each). Linkable interactive tools are the bet for domain authority. This is a multi-week build, not a content task.

**Status:** Designed, not started. Lowest urgency on this list because it's a build investment, not a publish-and-measure task — should not block any of B1–B5.

**Next action:** Re-read the design doc and decide whether the 2025-12 estimate still holds before committing.

**Source:** `docs/insights/2025-12-24-seo-tools-research.md`, `docs/plans/2025-12-24-greenwash-or-not-design.md`.

---

## Deprioritised / not doing

- **More long-tail blog posts** (e.g. "how to fold paper napkins", "are paper straws recyclable"). The keyword-targeting-strategy doc lists these but the insights doc concluded blog content doesn't earn links in this space, and the 40 published posts already cover most informational intent. Bar for new posts: must map to a product/category with measurable commercial intent and not duplicate an existing post.
- **Sitewide schema additions** (FAQ schema, HowTo schema, Review schema). Foundation is in. Adding more schema types without a ranking signal that says they'd help is premature optimisation.
- **Homepage trust signals / certification badges / cross-link sibling products** — these were items I'd been carrying forward as "P2.x" in conversation memory, but there's no written audit they came from. If they matter, they should come back as their own issues with concrete justification.

---

## How to use this doc

- One backlog item per measurable outcome. If you can't say what "done" looks like, it doesn't go here.
- Re-prioritise after each 4-week GSC pull. The data should drive the order, not intuition.
- When a B-item ships, move its summary to **What's already shipped** and delete the active entry.
- New ideas go in a draft GitHub issue first. They graduate here when there's evidence + a defined next action.

---

## Appendix: GSC analysis 2026-05-12

90-day window, 2026-02-11 → 2026-05-12, property `sc-domain:afida.com`.

**Headline numbers:**

| Metric | 90-day | Notes |
|---|---:|---|
| Total clicks | 327 | Flat |
| Total impressions | 81,010 | Up ~8× since Feb (240/day → 1,900/day) |
| Average CTR | 0.40% | Collapsed from ~1% in Feb to ~0.25% in late April |
| Average position | 12.0 | Drifted from ~9 to ~14 over the window |
| Brand share of clicks | 23% (76/327) | "afida" is the single biggest click source |
| Non-brand commercial clicks | ~30 | Spread across many low-volume queries |

**Top finding:** Impressions ~8×'d but clicks didn't move. New traffic is landing on informational blog posts that don't satisfy commercial intent. Top 5 impressions-no-clicks pages have 32,000 imp / 79 clicks combined — see B0 for the rewrite plan.

**Brand vs non-brand split:** After stripping "afida"-branded queries, the biggest non-brand impression source is `ice cream cups` (1,137 imp, 3 clicks, pos 13.8). Everything else commercial is sub-3-click in 90 days. Commercial discovery is *very* thin.

**Homepage:** Period-over-period clicks 61 → 35 (-43%) at unchanged pos 4.5. Likely a SERP-feature change or reduced brand-search volume, not a ranking issue. Watch, don't fix.

**Collections review (vs 2026-05-10 baseline memory):** Positions within ±0.5 across the board. 0 clicks on `/collections/restaurants` (250 imp), `/collections/coffee-shops` (97 imp), `/collections/vegware/cups-and-drinks` (227 imp) despite the shipped buying guides. Drives the B1 decision-point reframe.

**`/collections/takeaway`:** Pos 31.4, 204 imp, 1 click. Top queries (`biodegradable takeaway containers` pos 25, `biodegradable takeaway packaging` pos 62) sit at unwinnable positions. Confirms B5: content alone won't fix this. Treat as deprioritised; don't write a buying guide for it.

**High-CTR pattern winners** (see B0c): `/blog/paper-bag-for-food` 3.4%, `/blog/buy-custom-printed-coffee-cups-small-orders` 1.3%, `/blog/vegware-practical-guide-uk-food-business` 1.1%, `/blog/takeaway-boxes` 0.93%. All have URLs that imply commercial intent.

**Inputs to re-pull at 2026-06-08:**
- Performance overview, 90 days
- Page-level breakdown for `/collections/*` (same query as this snapshot)
- Page-level breakdown for the 5 B0 pages (to measure CTR delta after the rewrite ships)
- Period comparison: 2026-04-13 → 2026-05-12 vs 2026-05-13 → 2026-06-08
