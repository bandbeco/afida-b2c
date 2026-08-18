---
type: Plan
description: Overhaul of the compatible-lids feature; curated join table as sole truth, admin opened to all container types, cart lid reminder, and a propose/review/apply data pipeline.
status: active
timestamp: 2026-08-18
---

# Compatible Lids Overhaul

Successor to the [Matching Lids Configurator plan](/plans/2025-11-06-matching-lids-configurator.md). That build left a working `ProductCompatibleLid` join table but wrapped it in string heuristics: the admin panel only rendered when the product *name* contained "cup", lid candidates were found by `name LIKE '%lid%'` (missing most real lids, whose names are bare sizes like "80mm" with "Lids" only in the family name), and the storefront re-filtered curated rows through an oz-token regex duplicated in two places. Data was correspondingly sparse: 182 join rows across 26 products in production; hot-cups 20/70 mapped, every other container type locked out.

## What changes

1. **Join table becomes the sole display truth.** The product page renders `product.compatible_lids` (active only) directly. The regex filter layer and the dead `compatible_cup_sizes` path are deleted. The branded endpoint (`GET /branded_products/compatible_lids`) keeps an optional `size` filter solely because one customizable template spans many cup sizes; candidates still come only from the join table. `Product#oz_size_token` is the single surviving copy of the oz regex.
2. **Admin opened to every non-lid product** (cups, soup containers, ice-cream tubs, bowls, deli pots, portion pots). Lid candidacy = "lid" in the product name *or its family's name* (`Product.lid_candidates` / `#lid_product?`). The picker groups candidates by family, shows inactive badges, renders a default radio on every row (a default only counts when its lid is checked), and a save that unchecks the default promotes the first remaining lid.
3. **Cart reminder.** `Cart#lid_suggestions` (`LidSuggestions` PORO) suggests the curated default lid (fallback: first active) for each non-sample container with no compatible lid in the cart, deduped when containers share a lid. Rendered as cards in the cart's `#cart` turbo frame; adding posts the standard cart-items create with `cart_item[from_cart_page]`, which re-renders the frame so satisfied suggestions disappear.
4. **Data pipeline** (`lib/tasks/lid_mapping.rake`): `lids:export_inventory` (containers by category slug env-overridable + lids, with family fit-hints, oz sizes, diameters) → `lids:propose_mappings` (LLM-assisted proposals, one default per container, confidence + rationale, reviewed as CSV) → `lids:apply_mappings` (SKU-keyed, dry-run default, idempotent sync that leaves absent containers untouched).
5. **Safety**: `db/seeds/lid_compatibility.rb` (a `destroy_all` reseed) is deleted; lid mappings are curated production data and are never seeded. A one-time `lid_compatibility:prune_size_mismatched` task rewrites the family-seeded rows to what the old regex filter actually displayed, run against production before the filter-removal code deploys so the storefront never changes behind Laurent's back.

## Deploy sequencing

1. Prune prod data (behaviour-invisible under the old code; skips branded templates whose multi-size rows the configurator filters at runtime).
2. Deploy; verify a mapped hot-cup page lists identical lid SKUs pre/post and the configurator lids step still populates.
3. Run the pipeline; review the proposal CSV; dry-run apply; `APPLY=1`.
4. Spot-check a soup container / ice-cream tub page, the cart nudge appear/disappear cycle, and the family-grouped admin picker.

## Status

- 2026-08-18: All code phases built on branch `compatible-lids-overhaul` (tests green, 3,045 runs). Data prune, deploy and pipeline run pending.
