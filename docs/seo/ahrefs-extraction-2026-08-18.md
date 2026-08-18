---
type: Research
description: One-month Ahrefs Lite extraction burst; verdict is that authority is not the ranking constraint, commercial page coverage is, with a 444-keyword content gap and a spam-link spike documented.
status: active
timestamp: 2026-08-18
---

# Ahrefs Extraction (2026-08-18)

One-shot data pull from a single paid Ahrefs Lite month (signed up 2026-08-18, to be cancelled before the 2026-09-18 renewal). Purpose: answer the question the free tier could not, namely whether Afida's page-2/3 stall on commercial terms (see [SEO Measurement Checkpoint 2026-08-18](/seo/seo-audit-2026-08-18.md)) is an authority problem or a coverage problem, and extract every dataset with residual value before the subscription ends. All raw data lives in `docs/seo/data/ahrefs-2026-08/` (see [Data files](#data-files)); nothing below requires an active subscription to re-check.

Method: Ahrefs API v3 via the MCP connector. Competitor set from Ahrefs' own organic-competitors report for afida.com (GB): takeawaypackaging.co.uk, cupsdirect.co.uk, enviropack.org.uk, eventsupplies.co.uk, greenpak.supplies, cater4you.co.uk. Coverage bound: keyword pulls are each competitor's top 100 GB keywords by volume (position ≤ 20, volume ≥ 30; the API caps at 100 rows per call), so the gap files are a high-volume sample, not exhaustive. Referring-domain pulls are similarly the top 100 per domain by DR. ~25K of 100K monthly API units consumed.

## Headline verdict

Authority is not what is holding Afida back; commercial page coverage is. Every line of evidence points the same way:

1. The target keywords are near-zero difficulty. Afida's own commercial terms carry Ahrefs KD 0-4 (ice cream cups 700/mo KD 0, soup containers 300/mo KD 0, biodegradable takeaway containers 150/mo KD 2). The winnable-universe screen (volume ≥ 50, KD ≤ 15, at least one top-10 result with DR ≤ 25) returned 100 commercial keywords in Afida's lanes.
2. Weak domains win these SERPs. Across the nine head-term SERPs sampled: position 1 for "eco friendly food packaging" is a DR 3 exact-match domain; greenfeel.co.uk (DR 21) holds positions 3-7 on three SERPs with zero page-level referring domains; packgenie.co.uk (DR 3) is top-10 for "ice cream cups"; the "catering disposables" and "napkins wholesale" top-10s are full of DR 0-18 sites.
3. Low-DR competitors out-traffic Afida by orders of magnitude. cupsdirect.co.uk (DR 12) has an estimated 4.6K organic visits/mo, greenpak.supplies (DR 10) 2.2K, against Afida's 61. takeawaypackaging.co.uk, at exactly Afida's DR 33, gets 7.7K/mo from 755 ranking keywords across 141 organic pages; Afida ranks for 31 GB keywords.

Consequence: link building is not the next lever. Publishing commercial pages against the gap list below is.

## Findings

### 1. Content gap: 444 keywords, heavily skewed to zero difficulty

`content-gap-gb.csv` holds every keyword (vol ≥ 30, KD ≤ 20 filters per method above) where at least one of the six competitors ranks top-20 and Afida does not rank at all; `content-gap-gb-easy.csv` (388 rows) restricts to KD ≤ 10 and volume ≥ 50 with competitor-branded terms removed. Top of the easy file by volume, filtered here to plausibly on-brand lanes (paper/wood/bagasse; the raw file also contains off-brand plastic and film terms to skip or treat as own-brand-doctrine questions):

| Keyword | Vol/mo | KD | Best competitor (pos) |
|---|---|---|---|
| cake boxes | 5,700 | 2 | cater4you (14) |
| paper plates | 5,300 | 0 | cater4you (16) |
| food boxes | 3,500 | 0 | takeawaypackaging (1) |
| burger box | 3,000 | 0 | cater4you (8) |
| disposable plates | 2,800 | 0 | enviropack (4) |
| paper bags | 2,800 | 1 | cater4you (13) |
| greaseproof paper | 2,600 | 0 | takeawaypackaging (13) |
| paper cups | 2,600 | 9 | cupsdirect (14) |
| straws | 2,500 | 0 | eventsupplies (8) |
| foil trays | 2,200 | 0 | cupsdirect (3) |
| pizza boxes | 1,900 | 0 | takeawaypackaging (15) |
| paper napkins | 1,800 | 0 | eventsupplies (16) |
| food containers with lids | 1,700 | 4 | cater4you (11) |

The `keyword-universe-winnable-gb.csv` screen adds volumes for lanes Afida already stocks: napkins 4,300/mo KD 0, wooden cutlery 900/mo KD 0, paper coffee cups 800/mo KD 1. For context, Afida's entire current keyword footprint drives an estimated 61 visits/mo; the first three gap rows alone represent ~14,500 monthly searches at KD ≤ 2.

### 2. Page-type mismatch: Afida fields blog posts where winners field shop pages

The SERP sample (`serp-overviews-gb.csv`) is unambiguous about what ranks: collection/category pages and homepages, frequently with zero referring domains to the page. Afida's only head-term top-10 entry ("biodegradable takeaway containers", position 9) is a blog post, and its rankings for takeaway packaging, biodegradable packaging, soup containers and eco friendly containers all sit on `/blog/*` URLs. The competitors winning those terms hold them with buyable pages. The existing blog-to-shop CTA (Move 1) partially patches this, but the gap list should be closed with category/collection pages, not articles.

### 3. Afida's DR 33 is directory-inflated, and there is an active spam-link spike

The top referring domains by DR are directories and profile platforms (yell.com with 79 links, provenexpert, find-us-here, freelistingusa, framer/ghost subdomains, one flagged SPAM by Ahrefs). Worse, of the 100 referring domains first seen since late July (`afida.com-refdomains-new.csv`), 66 match spam/link-farm signatures (`.shop`/`.store`/`.top`/`.xyz` TLDs, names like `googleseocompany.shop`, `rankgrowthboost.shop`, `official-center-outrank-hq-search.store`), many sharing suspiciously identical mid-range DRs, consistent with one automated network. This looks like backlink spam or negative SEO rather than organic growth. No action needed now: Google generally ignores such links, and a disavow file is the only lever if rankings visibly degrade. Watch it at the ~2026-09-15 checkpoint; the raw file supports a future disavow if ever needed.

Net effect: Afida's true editorial authority is lower than DR 33 suggests, which makes finding 1 stronger, since even honest low-DR competitors beat us on coverage.

### 4. Link intersect: almost nothing worth chasing

Of 26 domains linking to at least two of the three modest-DR winners but not to Afida (`link-intersect-attainable.csv`), only three are genuinely acquirable: uksmallbusinessdirectory.co.uk (free listing), crunchbase.com (claimable company profile), kompass.com (B2B directory). The rest are platform artifacts. Given finding 3, adding more directory links is near-worthless for rankings anyway; claim the three if convenient, expect nothing from them.

### 5. A custom-print lane Afida does not touch

The winnable universe surfaces a high-commercial-value branded/custom cluster: printed greaseproof paper (250/mo, KD 1, CPC $3.50), custom greaseproof paper (300/mo, KD 2, $2.50), branded paper cups (250/mo, KD 4, $3.00), custom paper bags (450/mo, KD 3, $1.60), personalised/custom pizza boxes (650/mo combined, KD 0). takeawaypackaging.co.uk monetises exactly this with a `/branded-packaging/` section that ranks for the generic head term "greaseproof paper" (2,600/mo). Afida has a branded configurator asset (per the offers proposal) and no landing pages for any of these queries. This lane also matches the B2B plan's high-intent trade profile.

### 6. Corroborating details

* `/vegware` still showed at position 20 for "vegware" (1,800/mo) in Ahrefs data collected before today's 301 to `/collections/vegware` shipped; the consolidation ([log 2026-08-18](/log.md)) landed on a URL carrying live rankings, as intended.
* Ahrefs indexes both `/categories/cups-and-drinks/ice-cream-cups` (position 8, "ice cream cups with lids") and `/categories/cups-and-accessories/ice-cream-cups` (positions 11-31) as of different crawl dates. Verify the older path 301s cleanly; if both resolve 200, that is a live cannibalisation residue of the June renames.
* Afida's AI-surface presence is non-trivial (82 AI Overview appearances, 70 pages), consistent with the checkpoint's "napkins ranks but clickless, AI-shaped queries" finding.

## What this changes

The [B2B plan](/seo/b2b-organic-growth-plan-2026-07.md)'s wholesale-modifier thesis survives, but the priority inside it shifts: the binding constraint is that Afida has ~31 ranking keywords because it has few rankable commercial pages, while competitors field 100-400. The next unit of SEO work should be new or expanded category/collection pages picked off `content-gap-gb-easy.csv` in descending volume within brand fit (cake boxes, paper plates, burger boxes, pizza boxes, paper bags, greaseproof paper incl. printed, paper cups, paper napkins), each a buyable page, not an article. Candidate plays should enter the [backlog](/seo/backlog.md) through the usual re-prioritisation rather than being committed here; range gaps (does Afida stock cake boxes, paper plates, foil trays?) are an Afida-leadership question the gap list now lets us ask precisely, and connect to the own-brand import doctrine.

## Data files

All in `docs/seo/data/ahrefs-2026-08/` (CSV, GB market, pulled 2026-08-18):

| File | Rows | Content |
|---|---|---|
| `content-gap-gb.csv` | 444 | Competitor top-20 keywords Afida lacks, merged across the six competitors |
| `content-gap-gb-easy.csv` | 388 | Gap filtered to KD ≤ 10, vol ≥ 50, competitor brands removed |
| `keyword-universe-winnable-gb.csv` | 100 | Keywords Explorer screen: vol ≥ 50, KD ≤ 15, weak top-10 present |
| `serp-overviews-gb.csv` | 68 | Top-10 organic results with DR/UR/refdomains for 9 head terms |
| `<domain>-keywords-gb.csv` ×7 | 100 ea (afida: 31) | Per-domain top GB keywords |
| `<domain>-refdomains.csv` ×4 | 100 ea | Top referring domains by DR |
| `afida.com-refdomains-new.csv` | 100 | Referring domains first seen since 2026-06-15 (spam-spike evidence) |
| `link-intersect-attainable.csv` | 26 | Domains linking to ≥2 competitors but not Afida |
| `build_gap.py`, `build_link_intersect.py` | | Computation scripts (inputs stay on disk) |

## Housekeeping

Cancel the Ahrefs Lite subscription before 2026-09-18 unless a second extraction is scheduled; ~75K API units remain unused this cycle if anything else is wanted first (candidates: US-market gap, deeper refdomain history, position-history pulls for the September checkpoint).
