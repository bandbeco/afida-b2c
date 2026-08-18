---
type: Plan
description: Batched execution plan to close the Ahrefs content gap with rankable commercial pages; batch 1 is eight category-page retargets plus three new pages, gated on the 2026-10-15 GSC checkpoint.
status: active
timestamp: 2026-08-19
---

# Gap Coverage Plan (2026-08-19)

Executes the verdict of the [Ahrefs extraction](/seo/ahrefs-extraction-2026-08-18.md): Afida's ranking constraint is commercial page coverage, not authority. This plan turns the 388-keyword winnable gap into page-sized work, in gated batches.

Inputs: `docs/seo/data/ahrefs-2026-08/cluster-map-gb.csv` (every gap keyword mapped to a cluster, bucket, and target page; built by `build_clusters.py` against the 2026-08-19 production catalog snapshot, so bucket assignments reflect actual stock, not guesses). Companion: [Range Gaps proposal](/proposals/range-gaps-2026-08.md) covers the clusters Afida cannot rank for without stocking new products.

## Buckets

* Bucket 1, retarget existing pages: ~78K searches/mo across 20 clusters. The category page exists but does not target or win the head term.
* Bucket 2, build new pages for stocked products: ~30K/mo across 12 clusters. Products exist (verified in the catalog snapshot) but no dedicated rankable page does.
* Bucket 3, range decisions: ~13K/mo (cake boxes, chicken boxes). Out of this plan's hands; see the proposal.
* Skipped: ~96K/mo of off-brand terms (conventional plastic partyware, janitorial, ambiguous size generics). Deliberately not pursued; the eco positioning is worth more than this traffic.

## The page recipe

Every SERP the extraction sampled is won by a buyable page, usually with zero page-level links. So each target below gets the same treatment, and articles are explicitly not the instrument:

1. Head-first meta title and H1 (the product noun searchers type, per the July retitle lesson: modifiers only where they do not displace real-impression terms).
2. Hero intro plus buying-guide section on the page (the issue #106 pattern, as shipped for takeaway).
3. Category FAQs where missing.
4. Internal links: parent category, footer/nav where sensible, blog CTAs via the existing `target_*_slugs` machinery, cross-links between sibling clusters.
5. For cross-category builds, use a Collection (curated product set) rather than forcing the category tree.
6. Where an Afida blog post currently holds the cluster's only ranking, point its CTA at the new page and keep the post as support, not competition.

## Batch 1 (target: live by ~2026-09-01)

Retargets of existing category pages, by cluster volume:

| Page | Retarget head | Cluster vol/mo | Key terms (vol, KD) |
|---|---|---|---|
| `hot-cups` | Takeaway Coffee Cups | 15,800 | disposable coffee cups (1400, 1), coffee cups with lids (1400, 0), takeaway coffee cups (1100, 0), paper cups (2600, 9) |
| `plates-and-bowls` | Disposable & Paper Plates | 9,050 | paper plates (5300, 0), disposable plates (2800, 0), bagasse plates (350, 0) |
| `takeaway-boxes` | Food Boxes & Takeaway Boxes | 8,140 | food boxes (3500, 0), food box (1200, 0), takeaway boxes (900, 2) |
| `bags` | Paper Bags | 8,200 | paper bags (2800, 1), brown paper bags (1500, 0), sandwich bags (1100, 0), with handles (800, 1) |
| `aluminium-containers` | Foil Trays & Containers | 5,550 | foil trays (2200, 0), foil trays with lids (800, 0), foil containers (500, 0) |
| `napkins` | Paper Napkins & Serviettes | 5,290 | paper napkins (1800, 0), serviettes (1600, 0), serviette (900, 0) |
| `greaseproof-and-wraps` | Greaseproof Paper | 3,700 | greaseproof paper (2600, 0), sheets (600, 0), bags (250, 0) |
| `pizza-boxes` | Pizza Boxes | 2,450 | pizza boxes (1900, 0), 12 inch (200, 0), for sale (250, 0) |

New pages (products verified in stock):

| New page | Cluster vol/mo | Built from |
|---|---|---|
| Burger Boxes | 5,450 | bagasse burger boxes ×3, kraft burger boxes, burger chip boxes, burger trays, burger wraps |
| Platter Boxes & Catering Trays | 6,240 | Platter Box range with inserts, sandwich wedges/cartons, microflute trays |
| Ice Cream Tubs | 2,950 | printed and plain paper tubs (4/6/8oz), tub lids, ice cream pots; split out of `ice-cream-cups` |

Structural fix shipped with the batch: resolve the `cups-and-drinks/ice-cream-cups` vs `cups-and-accessories/ice-cream-cups` dual-URL residue (verify the stale path 301s; Ahrefs saw both ranking).

## Batch 2 (gated)

In descending priority once the gate passes: the custom-print lane (expand `branded-products` beyond coffee cups; printed greaseproof landing page targets the stocked printed sheets; 3,250/mo plus the highest CPCs in the dataset), dessert cups (2,850), smoothie cups (2,650), food trays (2,550), fish & chip boxes (1,300), noodle boxes via kraft takeaway boxes (850), microwavable containers (750), plus second-tier retargets: cutlery to Wooden Cutlery (3,950), bowls (2,350), sandwich & wrap boxes (2,150), soup containers (1,900), deli, salad, portion/sauce pots. Wholesale-modifier variants layer onto whichever batch-1 pages show movement, per the B2B plan.

## Gate and measurement

* Ship batch 1 by ~2026-09-01 so the 2026-10-15 GSC checkpoint reads ~6 weeks of data (content settles in 4-8 weeks; the September 15 checkpoint is an early peek only, not the judgment).
* Pass: at least 5 of the 11 batch-1 targets have an Afida URL in GSC top-20 for their head term, or clearly rising impressions on the target page. Then run batch 2.
* Fail: coverage was not the constraint (or not the only one); stop building, diagnose with the September/October GSC data before spending more.
* Known risk, from the napkins lesson: page-1 positions on AI-shaped SERPs can be clickless. Track clicks, not just position, and prefer the transactional heads this plan targets.

## Ownership

Page work (retargets, builds, internal links, structural fix) sits with the dev retainer. Bucket-3 stock decisions sit with Afida leadership via the [Range Gaps proposal](/proposals/range-gaps-2026-08.md). The [SEO backlog](/seo/backlog.md) tracks per-page execution.
