---
type: Plan
description: Operative B2B organic growth plan; shifts targeting to high-intent UK B2B queries (wholesale/bulk modifiers, brand-stockist terms) on commercial pages.
status: active
timestamp: 2026-07-07
---

# B2B Organic Growth Plan — afida.com — 2026-07-06 (updated 2026-07-07 with fresh GSC export)

**Goal:** grow organic traffic from *high-intent UK B2B buyers* (cafés, restaurants, delis, takeaways restocking supplies), not raw traffic.

**Sources:** production DB (2026-07-06), Datafa.st (30d to 2026-07-06), GSC export 2026-07-07 (last 3 months, `afida.com-Performance-on-Search-2026-07-07.zip`), SEO code-surface audit (this session), live UK SERP checks (2026-07-06), Ahrefs research (`docs/seo/ahrefs-keyword-research-2025-01-17.md`), existing strategy docs.

---

## 1. Diagnosis: the engine works, the targeting is wrong

**Traffic is compounding but it is the wrong traffic.** Last 30 days: 3,058 visitors, £2,978 revenue, 32 payments. Google is the #1 source (1,556 visitors) but carries only £449 of attributed revenue vs £1,325 for Direct. Where organic actually lands:

| Surface | Visitors/30d | Attributed revenue |
|---|--:|--:|
| Blog | ~700 | £0 |
| Product pages | ~1,200 | ~£100 |
| Category pages | ~100 | £0 |
| Collection pages | ~0 | £0 |

The commercial surfaces built for B2B buyers (categories, collections) receive almost nothing, while the blog (74% of GSC impressions) attracts informational searchers who do not buy. Brand still takes 55% of clicks. Every commercial head term sits on Google page 2-3.

**What a high-intent B2B searcher actually types** (Ahrefs + SERP evidence): `takeaway containers wholesale` (150/mo, difficulty 1), `pizza boxes wholesale` (100/mo, diff 0), `cold cups wholesale` (80/mo), `paper cups wholesale` (60/mo, CPC £1.40), `vegware stockist uk`, `[product] for restaurants/cafés`. Individually tiny, but the pattern stacks across all 33 categories, difficulty is near zero, and CPCs of £0.70-£2.50 prove commercial value. **Nobody restocking a café searches "eco friendly packaging"; they search the product + wholesale/bulk, or the brand they already use.**

**The 2026-07-07 GSC export quantifies exactly how much of this demand Afida sees and loses.** Last 3 months, non-brand queries bucketed by intent:

| High-intent bucket | Queries | Impressions | Clicks |
|---|--:|--:|--:|
| Wholesale / bulk / supplier / catering | 65 | 3,214 | **0** |
| Vegware / NatureFlex brand terms | 25 | 3,067 | **0** |
| "for restaurants/cafés/hotels…" template | 19 | 1,107 | 4 |
| Custom / printed / branded | 14 | 621 | 1 |

~8,000 quarterly impressions of pure trade-buyer demand, 5 clicks. Google already shows Afida for these queries; the pages and titles just don't win the click. Standouts: `takeaway packaging suppliers` 347 imp at pos 18.7; `natureflex bags` 570 imp at pos 11.8; `vegware cups` 377 imp at pos 19.7; and, most damning, `napkins for restaurants` (302 imp, pos 9.7) and `paper napkins for restaurants` (190 imp, pos 6.7) are **already page 1 with zero clicks**, because the ranking URL is a blog guide, not a buyable category page.

**Live UK SERP checks (2026-07-06) confirm the lane is winnable:**
- `soup containers uk wholesale`: won by small sites (RR Packaging #1, Fudora #6, TBH #7) whose titles literally read "Soup Containers & Lids Wholesale UK | Kraft, White…" with case pricing in the snippet. Not authority sites; title/offer match wins.
- `vegware stockist uk`: **Afida already ranks #9**, behind vegware.com, Nisbets, Cooksmill. Page 1 on a pure trade-buyer query; pushable.
- `ice cream cups uk`: split intent; half the SERP is custom-print (Vistaprint, PackGenie, Limepack), half is plain eco stock (Greenfeel #3). Afida has assets for both.
- `takeaway packaging`: won by the exact-match domain takeawaypackaging.co.uk plus national distributors (JJ Foodservice). Confirms the backlog B5 verdict: structural, do not spend content effort there.

**Proven templates already on the site:**
- `sustainable packaging for restaurants` holds position ~2.7 and converts. The "[product/packaging] for [business type]" template works.
- Product rich results: 132 clicks / 28.9k impressions per quarter; structured data pulls weight.
- The B0 blog meta rewrite shipped (verified in prod today) and the 5 high-impression posts now carry café/restaurant-angled titles.

**Open threats:**
- June category-rename 404s: the damage is now measurable. Daily clicks averaged 10.0 (Jun 8-21, pre-rename) vs 6.9 (Jun 27-Jul 5), a ~31% drop. The 301s went live Jul 2 but Jul 3-5 shows no recovery yet; the new category URLs are barely indexed (new ice-cream-cups URL: 34 impressions vs 7,362 on the dead old URL). GSC reindex requests and sitemap resubmission are still not done, and Category has no slug-history auto-redirect, so the next admin rename silently 404s again.
- 82 unpublished Outrank drafts (was 31 in May); the auto-import keeps running with no gate.
- Datafast purchase goal caught 8 of 32 payments; revenue attribution stays directional until the webhook visitor-id investigation lands.

**Measurement caveat discovered in the 07-07 export: AI fan-out queries now pollute impressions.** 254 long multi-qualifier queries (6+ words, clearly assistant-generated, e.g. "best paper napkin brands print aesthetic appeal", "bazaar coffee website evidence portioning cups lids containers") account for ~18.6k impressions and 7 clicks; Afida ranks top-6 on 103 of them. Two consequences: (a) impression growth is no longer a meaningful KPI, judge everything on clicks and on positions for a fixed hand-picked term set; (b) Afida's content is evidently being retrieved by AI search surfaces (corroborated by ~30 ChatGPT referrals/month in Datafa.st), which validates the GEO angle in W1/W8 at zero extra cost.

---

## 2. Strategy in one line

Re-point every commercial surface at the UK trade buyer restocking a food business: trade-modifier titles (wholesale, bulk, by the case), business-type landing templates, and brand-stockist terms; stop feeding the informational blog lane.

---

## 3. Workstreams

### W0. Protect the base (this week, ~2h + half-day dev)
1. **GSC housekeeping (30 min, manual):** request reindexing of the top renamed URLs (old: ice-cream-cups, soup-containers, straws, aluminium-containers; new: cups-and-accessories/*, food-containers/*), resubmit the sitemap. Open since the 2026-07-02 audit; days matter for 301 equity recovery.
2. **Slug-history auto-redirect on Category (dev):** friendly_id-style history so admin renames can never 404 again. Renames provably recur.
3. **New-category content gaps:** `bowls-and-lids` and `portion-pots-and-lids` (both born in the June restructure) have **no buying guide** and inherit no ranking history; write their guides + meta. Add a code fallback for category `meta_description` (currently ships an empty tag when blank; `categories/show.html.erb:10`).
4. **Two vegware filter URLs are still live 404s** (found 2026-07-07): `/collections/vegware/cups-and-drinks` (724 imp/quarter in GSC) and `/collections/vegware/hot-food` still use the pre-rename category slugs and 404; the June redirect map only covered `/categories/*`. Add the two 301s.

### W1. Trade-intent retitle of all commercial pages (highest leverage per hour)
The SERP winners' pattern, applied to Afida's 33 categories + key collections:

- **Meta titles:** `[Product] | Wholesale UK | [size range] | Afida` style; work in "bulk"/"by the case" and the size range (e.g. "Soup Containers & Lids | Wholesale UK | 8oz-32oz | Afida"). Keep the December keyword doc's terms but lead with the trade modifier, not "eco".
- **Meta descriptions:** name the buyer and the economics: case size, price-per-case or per-unit anchor, next-day delivery, free delivery threshold. This is what wins the click on these SERPs.
- ~~**Render the question-style H2:** `category_question_heading` is written and tested but never rendered.~~ **Dropped 2026-07-20.** It is not an unrendered leftover: it was deliberately removed from the category page in March (commit `d60461d5`, hero + buying guide, closing #106), and `categories_controller_test.rb` carries a "show page does not render question heading" test guarding that decision. The hero already carries the category name prominently, so a second question heading above the grid is redundant chrome. Not worth overturning a prior design decision for a speculative GEO gain.
- Data plumbing exists (pricing_tiers, pac_size) if we want per-case pricing shown on-page; the meta rewrite itself is a data change, not code.

**Measure:** positions on the "wholesale term set" (one term per category from the Ahrefs doc) + category-page clicks, at each 4-weekly pull.

### W2. Business-type templates (replicate the one proven winner)
`…for restaurants` ranks 2.8; `/collections/coffee-shops` sits at 11.6 and has started earning clicks (4 this quarter, vs 0 at the May snapshot), the first positive Move 2 signal. `/collections/bakeries` is at pos 5.7 on a tiny base. The extension list (bakeries, ice-cream-parlours, pubs-bars, hotels, smoothie-juice-bars) **stays gated on the 2026-07-17 measurement** per the backlog B1 decision rule; do not write guides before the gate says the pattern moves clicks.

One addition the 07-07 export demands: **capture the page-1-no-clicks "for restaurants" terms.** `napkins for restaurants` (pos 9.7) and `paper napkins for restaurants` (pos 6.7) rank via the blog guide and win nothing. Give the napkins category a "for restaurants & cafés" content block + FAQ so the buyable page can take the ranking, and make the blog post's first screen link straight to it. Same pattern wherever a blog URL holds a page-1 commercial-intent position.

Ungated hygiene that should happen regardless:
- ~~Kill the duplicate collections~~ **Resolved 2026-07-07: not duplicates.** The singular-slug rows (`bakery`, `coffee-shop`, `restaurant`, `smoothie-bar`, `ice-cream`, second `takeaway`) are **sample packs** (`sample_pack: true`), served under `/sample-packs/:slug` on their own route; `Collection.regular` scopes them apart and `/sample-packs/bakery` even earns clicks (4, pos 18.4). No merge needed; leave them alone.
- **Internal links to collections.** Collections get ~zero visits partly because almost nothing links to them: add the business-type collections to the footer (categories already are), and ship the reciprocal blog↔collection links from backlog B0b.

### W3. Own the stockist/brand lane (cheapest high-intent wins on the board)
A trade buyer searching `vegware stockist uk` or `natureflex bags` is choosing a supplier right now. The 07-07 export shows this whole lane at **3,067 impressions / 0 clicks**: `natureflex bags` pos 11.8, `vegware cups` pos 19.7, `vegware` pos 23.3. All page 2, all winnable, all currently worth nothing.

- **Fix the vegware page split first.** Two Afida pages compete for the same brand queries: the static `/vegware` landing page (1,335 imp, pos 20.6) and `/collections/vegware` (590 imp, pos 11.7). The collection page ranks 9 positions better with less exposure. Consolidate: 301 `/vegware` into `/collections/vegware` (or strip/canonicalise it), so one URL accumulates all the brand-term signals.
- Push `/collections/vegware` from #9 → top 5: sitewide internal link ("Official Vegware stockist" in footer/homepage), an FAQ targeting "where can I buy Vegware in the UK", and **add the vegware category-filter pages to the sitemap** (indexable + unique curated content, but absent from `sitemap_generator_service.rb`; code gap found in audit).
- Same play for NatureFlex (category exists with a 5.3k-char guide; `natureflex bags` at pos 11.8 with 570 imp is the single most valuable page-2 term on the board).
- Ask Vegware for a stockist listing/link on vegware.com (legitimate, high-authority, exactly-relevant backlink; likely the single best link Afida can get).

### W4. Custom-print lane (SERP says the intent is there)
Half the `ice cream cups uk` SERP is custom-print players, `/blog/buy-custom-printed-coffee-cups-small-orders` is a proven CTR outlier (1.28% at pos 9.3), and `printed kraft paper bags` carries a £2.00 CPC. Afida has `/branding` + `/branded-products/*` already.

- Target the "custom printed [product] small orders / low MOQ UK" cluster on the branded-product pages (meta + H1 + a short MOQ/lead-time block; low-MOQ is the differentiator vs Vistaprint-tier players).
- Internally link branded-products from the matching plain categories ("Need these printed with your logo?").
- This is also the SEO groundwork for the growth plan's Phase 2 print-brokerage bet; where custom print ultimately lives (Afida vs Brand Brothers) is Tariq's call, flagged in the growth plan.

### W5. Blog: convert what exists, stop the pile-up
- **Populate shop-CTA targets on the 23 published posts that lack them** (17/40 done). Several missing ones are commercial-adjacent: takeaway-boxes, disposable-coffee-cups, eco-straws, compostable-food-packaging, buy-custom-printed-coffee-cups-small-orders. Data change in admin, no code.
- **Wire the dead internal-link fields (small dev):** `target_product_slugs` is stored but ignored by `blog_post_shop_links`, and `internal_link_targets` is never rendered. Products are where organic already lands; blog→product links close the loop.
- **Outrank decision (with Tariq):** drafts grew 31 → 82 in two months. Either configure a human-approval gate or pause the subscription; the backlog B4 questions (spend vs on-brand publish rate) are now urgent purely from the pile-up rate.
- New posts only for commercial clusters (wholesale/custom-print angles). The informational lane is saturated and proven to convert £0.

### W6. Variant architecture (the structural dev fix, phased)
649 active products across 137 families; `hot-cups` alone lists 79 products, `cold-cups-and-lids` 60. Every size/colour variant is a separate indexable URL with near-identical `description_standard`, no `ProductGroup`/`isVariantOf` schema, no cross-canonical. Sibling URLs almost certainly cannibalise each other on "double wall coffee cups"-type queries.

- **Phase A (safe, ship soon):** emit `ProductGroup` + `isVariantOf` JSON-LD per family; make sure size/pack tokens differentiate every meta title/description (generated_title mostly does this already).
- **Phase B (only with data):** at the July/August GSC pulls, check query-level reports for sibling URLs swapping positions on the same query; where confirmed, pick a family hero URL and canonicalise the rest. Do **not** blanket-canonicalise: individually-ranking oddballs (food rotation labels, bin liners, till rolls are among the top organic product pages right now) must keep their own URLs.

### W7. Technical hygiene batch (one dev afternoon, from the code audit)
- **Feed the Merchant listings surface.** The 07-07 export shows Merchant listings converting at **26.7% CTR (31 clicks off just 116 impressions, pos 4.9)**, versus 0.45% for product snippets. This is the highest-CTR surface Afida has. Audit `/feeds/google-merchant.xml` coverage: every active product with price, availability, GTIN and image; fix any exclusions. Free listings, zero content work.
- `noindex` the `/search` page (thin, indexable, no meta description; mirror the `quick_add` X-Robots-Tag approach).
- Deduplicate the doubled canonical tag on blog posts.
- Keyword-bearing homepage H1 (currently the marquee) and an `ItemList` block for the homepage bestsellers.
- Cache the sitemap response; standardise JSON-LD image URLs on `rails_storage_proxy_url`.
- Retire or extend the dormant `UrlRedirect` middleware (only matches legacy `/product/` singular paths).

### W8. Authority, kept cheap
- Stockist/directory links: Vegware stockist page (W3), UK hospitality/trade directories, local chamber, sustainable-business directories. Low effort, exactly-relevant.
- The "Greenwash or Not?" linkable tool (backlog B6) remains the one big authority bet; decide after the July 17 measurement, not before.
- GEO/AI: ChatGPT already refers ~30 visitors/mo and robots.txt welcomes AI crawlers. FAQ schema is live; rendering the question-H2s (W1) and keeping the honest-compostability voice is the play. No extra spend.

---

## 4. What we deliberately do NOT do

- No new informational blog content (74% of impressions, £0 revenue; lesson paid for).
- No content spend on `/collections/takeaway` head terms (exact-match-domain SERP; structural loss).
- No buying-guide batch 2 before the July 17 gate says batch 1 moved clicks.
- No blanket variant canonicalisation without query-level cannibalisation evidence.
- No US/international SEO while shipping stays UK-only (~34% of traffic already can't buy).

---

## 5. Sequencing (fits ~4h/week + occasional dev block)

| When | What |
|---|---|
| Week of Jul 6 | W0 (GSC requests, slug-history redirect, 2 missing guides) + W5 CTA targets |
| Week of Jul 13 | W1 category retitles (data pass over 33 categories), W2 collection internal links |
| **Jul 17** | **GSC measurement checkpoint** (Moves 1-2 + 404 recovery). Re-gate W2 guides; check W1 baseline |
| Weeks of Jul 20-27 | W3 vegware/stockist push + W6 Phase A + W7 hygiene batch (dev block) |
| August | W4 custom-print cluster; W2 guides if gate passed; Outrank decision with Tariq |
| Every 4 weeks | GSC pull against the KPI set below; reprioritise in `docs/seo/backlog.md` |

## 6. KPIs (high-intent, not vanity)

Impressions are no longer a usable KPI: AI fan-out queries inflate them (~18.6k impressions across 254 assistant-shaped queries this quarter, 7 clicks). Judge on clicks and on positions for a fixed term set.

1. **Non-brand clicks to commercial pages** (categories + collections + products), weekly from GSC. The single headline number for this plan.
2. Positions on the **wholesale term set** (one "[product] wholesale" term per top category) and the **business-type set** ("packaging for restaurants/cafés/bakeries…"). Baseline 2026-07-07: the four high-intent buckets total ~8,000 imp / 5 clicks; success in 90 days = those buckets earning 30+ clicks/quarter.
3. Stockist lane: `natureflex bags` (11.8), `vegware cups` (19.7), `vegware` (23.3), `vegware stockist uk` (#9 SERP) positions; plus one consolidated vegware URL (W3).
4. Blog → shop CTA click-throughs (Move 1) and blog-assisted revenue once purchase tracking is trustworthy.
5. Watchdogs: daily clicks back above the pre-rename ~10/day baseline (404 recovery); 404s in GSC coverage trending to zero; Merchant-listings clicks (26.7% CTR surface) growing with feed coverage.

Revenue-side context metrics (owned by the marketing strategy doc, not this plan): UK revenue, sample requests, accounts with 2+ orders.
