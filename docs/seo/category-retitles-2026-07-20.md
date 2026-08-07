---
type: Draft
description: W1 trade-intent retitle of all 33 category pages plus meta descriptions for the 18 that lacked them; applied to production 2026-07-20.
status: shipped
timestamp: 2026-07-20
---

# Category retitles (W1), 2026-07-20

**Why:** the wholesale/bulk query bucket showed 45 queries / 969 impressions / **0 clicks** in the 28 days to 2026-07-17 ([SEO Audit 2026-07-19](/seo/seo-audit-2026-07-19.md) §7). Google already shows Afida for these searches; the titles did not win the click. This is workstream W1 of the [B2B plan](/seo/b2b-organic-growth-plan-2026-07.md).

**Scope applied:** 23 `meta_title` rewrites (17 leaf + 6 parent), 18 new `meta_description` values (12 leaf + 6 parent). Every category now has both fields written; no category relies on the generated fallback. All 33 live-verified by curl the same day. Data-only change, no deploy.

## Targeting principle (revised by GSC evidence)

The plan's original shape was `[Product] | Wholesale UK | [size range] | Afida` on every page. The 28-day query data argued against applying that mechanically: real demand on most of these pages is **plain product nouns and specs**, not the wholesale modifier. Examples: `aluminium container(s)` 261 imp, `carrier bags` and variants 221 imp, wooden/disposable cutlery 770 imp, `shelf life label(s)`, `smoothie cup sizes`, `12 inch kraft pizza boxes`.

So the rule used was: **lead with the noun searchers type, then the differentiating spec, and add "Wholesale UK" or "Bulk UK" only where it does not displace a term with real impressions.** A title promising wholesale on a page that ranks for "aluminium container" wins fewer clicks, not more.

Price anchors (`from £0.02/unit`) were removed from hot-cups, straws and cutlery: the characters buy more as specs, and the anchors go stale silently. They were left in place where they already existed and no better spec was available (ice-cream-cups, bagasse-containers, food-containers-and-lids, takeaway-boxes).

## Titles applied

| Category | Before | After |
|---|---|---|
| hot-cups | Disposable Coffee Cups & Lids \| from £0.02 \| Afida | Takeaway Coffee Cups & Lids \| Wholesale UK \| Afida |
| cold-cups-and-lids | Cold Cups + Lids \| Afida | Cold Cups & Lids \| Smoothie Cups, 8-20oz \| Afida |
| hot-cup-lids | Hot Cup Lids \| Afida | Hot Cup Lids \| Sip-Thru & Flat, 62-115 Series \| Afida |
| cup-accessories | Cup Accessories \| Afida | Cup Carriers, Sleeves & Stirrers \| Bulk UK \| Afida |
| straws | Paper Straws \| Biodegradable from £0.02/unit \| Afida | Paper Straws \| Wholesale UK \| Bubble Tea & Slush \| Afida |
| bags | Brown Paper Bags \| Bags with Handles \| Afida | Paper Carrier Bags \| Flat & Twisted Handle \| Bulk UK \| Afida |
| greaseproof-and-wraps | Greaseproof & Wraps \| Afida | Greaseproof Paper & Deli Wraps \| Printed or Plain \| Afida |
| deli-containers | Deli Containers \| Afida | Deli Containers & Pots \| Round & Hinged, Bulk UK \| Afida |
| salad-boxes | Salad Boxes \| Afida | Salad Boxes & Sushi Trays \| Window Boxes, Bulk UK \| Afida |
| sandwich-and-wrap-boxes | Sandwich & Wrap Boxes \| Afida | Sandwich Wedges & Wrap Boxes \| Wholesale UK \| Afida |
| aluminium-containers | Aluminium Containers \| Afida | Aluminium Foil Food Containers & Lids \| No.1-No.12 \| Afida |
| bin-liners | Bin Liners \| Afida | Bin Liners & Refuse Sacks \| 8L to 240L \| Bulk UK \| Afida |
| gloves-and-cleaning | Gloves & Cleaning \| Afida | Food Handling Gloves & Centrefeed Rolls \| Bulk UK \| Afida |
| labels-and-stickers | Labels & Stickers \| Afida | Food Rotation & Shelf Life Labels \| Bulk UK \| Afida |
| till-rolls | Till Rolls \| Afida | Thermal Till Rolls \| PDQ & Receipt Rolls \| Bulk UK \| Afida |
| plates-and-bowls | Paper Plates \| Disposable & Bamboo Plates \| Afida | Disposable Plates & Bowls \| Bagasse, Catering Bulk \| Afida |
| cutlery | Wooden Cutlery \| Compostable from £0.08/unit \| Afida | Wooden Cutlery \| Birchwood Forks, Knives & Spoons \| Afida |

The six parents (cups-and-accessories, food-containers, tableware, bags-and-wraps, cold-food-and-salads, supplies-and-essentials) went from bare `[Name] | Afida` to `[Name] | Wholesale Catering Supplies UK | Afida`.

Untouched because they already followed the pattern: napkins (shipped 2026-07-19), bowls-and-lids, portion-pots-and-lids, soup-containers, pizza-boxes, natureflex-bags, ice-cream-cups, bagasse-containers, food-containers-and-lids, takeaway-boxes.

## Meta descriptions

Written for the 12 leaf categories that had none (cold-cups-and-lids, hot-cup-lids, cup-accessories, greaseproof-and-wraps, deli-containers, salad-boxes, sandwich-and-wrap-boxes, aluminium-containers, bin-liners, gloves-and-cleaning, labels-and-stickers, till-rolls) and all 6 parents. Each names the buyer, the product specifics, "by the case", and the £100 free-delivery threshold, matching the voice of the existing 16.

## Measurement

At the ~2026-08-16 pull, judge on: clicks to `/categories/*` (27 in the 28 days to 2026-07-17, against 969 wholesale-bucket impressions that produced none), and positions on the per-category head terms above.

**Caveat carried forward:** cutlery (pos 47) and straws (pos 32.8) are far enough back that titles alone will not move them. They were retitled because it is free, but a flat result there is not evidence the retitles failed. Judge the play on pages already in the 5-20 range.
