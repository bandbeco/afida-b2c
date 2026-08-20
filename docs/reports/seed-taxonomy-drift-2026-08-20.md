---
type: Report
description: Why bin/setup stopped seeding, the reconstructed 33-category taxonomy the seed CSVs now carry, and the two open slug questions.
status: shipped
timestamp: 2026-08-20
---

# Seed taxonomy drift, 2026-08-20

**Symptom:** `bin/setup` aborted seeding. `Category` rejected five slugs in
`lib/data/categories.csv` (`cups-and-lids`, `takeaway-containers`,
`takeaway-extras`, `plates-trays`, `bagasse-eco-range`) via
`RESERVED_REDIRECT_SLUGS`, added in `69ffee4f`.

## Root cause

`bin/rails db:prepare` on a fresh database loads `db/schema.rb` and runs seeds —
it **never runs migrations**. The nested taxonomy was built by
`db/migrate/20260306204621_create_category_hierarchy.rb`, so that migration does
not execute for a new developer. The seed CSVs were the *input* to it: the flat
March taxonomy.

Every developer set up since March therefore received a flat, five-months-stale
category tree. The reserved-slug validation did not cause the drift — it turned a
silent wrong into a loud failure. `products.csv` compounded it: all 98 products
hung off seven flat slugs, three of them reserved, so unblocking the categories
alone would have skipped 64 products while `bin/setup` reported success.

## Fix

`categories.csv` gained a `parent_slug` column and now carries the current
33-row taxonomy (6 parents + 27 subcategories). `db/seeds.rb` and
`lib/tasks/import_categories.rake` load it in two passes (parents, then
children). `products.csv` was remapped onto leaf categories: 64 of 98 rows moved.

Three flat categories split rather than renaming 1:1 — a wholesale rename per the
March migration would be wrong today, because later admin work subdivided them:

| Flat slug | Now |
|---|---|
| cups-and-lids (36) | hot-cups 17, cold-cups-and-lids 11, hot-cup-lids 8 |
| takeaway-containers (16) | bowls-and-lids 8, soup-containers 5, takeaway-boxes 3 |
| takeaway-extras (12) | cup-accessories 4, bags 4, cutlery 4 |

The `takeaway-extras` split replays the regex rules in the hierarchy migration's
`redistribute_takeaway_extras` verbatim, so seed data lands where that migration
actually put those products (12/12 matched, no fallbacks).

`test/data/seed_data_test.rb` pins the shape: parent resolution, the 6/27 counts,
no seeded slug reserved, no top-level slug shadowed by a static route redirect,
and every `products.csv` slug resolving to a leaf. It reads files and constants
only — no database, no fixtures.

## Reconstruction and its assumptions

Production was not reachable, so the taxonomy was reconstructed from four
independent in-repo sources that agree on exactly 33: the hierarchy migration,
`CATEGORY_QUESTION_HEADINGS` / `RELATED_CATEGORIES` in `categories_helper.rb`,
the backfill map in `20260708123508_backfill_category_slug_redirects.rb`, and
[Category Retitles (W1)](/seo/category-retitles-2026-07-20.md), whose 17 retitled
+ 10 untouched leaves + 6 parents = 33 "live-verified by curl".

Two items were unconfirmed at first pass. **Both are now settled** against
`https://afida.com/sitemap.xml`, read 2026-08-20, which lists exactly 33 category
URLs and is therefore the authority — production, not the March migration:

1. **`hot-cup-lids` is live**, confirming the seeded slug. So the three places
   still keying off `cup-lids` were genuinely stale, and each failed silently:
   `RELATED_CATEGORIES` rendered one fewer tile on four pages,
   `CATEGORY_QUESTION_HEADINGS` fell back, and `rake categories:seed_faqs`
   printed `SKIP: No category with slug 'cup-lids'`, leaving that page with no
   FAQ block and no FAQPage schema. All three are fixed.
   `20260319223300_populate_cup_lids_buying_guide.rb` is deliberately left alone:
   it is historical, it ran while the slug was still `cup-lids`, and the later
   rename carried its `buying_guide` across with the record.
2. **`aluminium-containers` sits under `food-containers`, not `tableware`** — the
   first pass seeded it wrongly. The merchant-feed grouping was right and the
   hierarchy migration is simply out of date, having created it under
   `tableware` before a later admin move. Corrected, so `tableware` has 3
   subcategories and `food-containers` 8.

The live tree is now pinned verbatim as `LIVE_TAXONOMY` in
`test/data/seed_data_test.rb`, alongside three new tests asserting that every
slug referenced by `RELATED_CATEGORIES`, `CATEGORY_QUESTION_HEADINGS` and
`config/category_faqs.yml` actually exists — the class of silent drift that
caused this.

**Lesson for future reconstruction:** `create_category_hierarchy` is a snapshot
of March, not a description of the taxonomy. Categories have been renamed and
re-parented through the admin UI since, and only production records that.

Two FAQ gaps surfaced while checking: `config/category_faqs.yml` has no entry for
`bowls-and-lids` or `portion-pots-and-lids`, both created after that file was
written. Content task, not a drift bug.

`branded-packaging` was deliberately excluded: `create_category_hierarchy_test.rb`
names it, but that test asserts only against its own constants, the migration
never creates it, `/branded-packaging` is a route that 301s to `/branding`, and
`shop_page_filters_test.rb` asserts it must not appear.

## Review follow-ups (applied)

A code-review pass over the branch found five defects, all fixed:

* **Blank CSV cells nulled production copy.** Both writers assigned
  `meta_title`/`meta_description`/`description` unconditionally, so
  `rake categories:import` — the documented SEO-metadata path — would have
  cleared those fields on the 23 rows this file ships blank. Both now assign only
  what the CSV carries; a blank cell means "no opinion", not "clear it".
* **Five ported titles were pre-retitle values.** `hot-cups`, `straws`, `bags`,
  `plates-and-bowls` and `cutlery` inherited copy from the flat categories they
  descend from, which is the *Before* column of
  [Category Retitles (W1)](/seo/category-retitles-2026-07-20.md). They now carry
  the shipped values, pinned by `RETITLED_2026_07_20` in the seed test.
* **Re-seeding an existing database left dead categories in the nav.** Seeding
  never deletes, so a database predating the restructure keeps the old flat
  top-level rows, which sort ahead of the real parents in the nav and footer and
  link to paths `routes.rb` 301s away. `db/seeds.rb` now warns, listing each
  orphan with its position and product count. It does not delete: that is a
  judgement call for whoever reads the warning.
* **A missing `parent_slug` column silently flattened the taxonomy.** Both
  loaders now refuse to run without it.
* **The rake task swallowed structural errors and exited 0.** An unknown parent
  landed in the blanket per-row `rescue`, so a run that skipped half the taxonomy
  looked clean to a calling script. It now exits non-zero when any row failed.

The review also re-raised the `hot-cup-lids` question above, adding one source:
`20260319223300_populate_cup_lids_buying_guide.rb` keys off `cup-lids` too. That
does not settle it — production is still the only authority.

## Still open

`RESERVED_REDIRECT_SLUGS` is mis-scoped in both directions. `config/routes.rb`
statically 301s 12 single-segment `/categories/:slug` paths, but only 5 are
listed. The other 7 are live *subcategory* slugs whose canonical URL is nested,
so the flat redirect never shadows them — correct today, but nothing stops a
future **top-level** category from claiming one and being 301'd away before the
app runs. Conversely the validation is unconditional, so it also rejects the 5 as
subcategory slugs, where they would be safe. The precise rule is *a top-level
category's slug must not collide with a static one-segment category redirect*:
scope the validation to `parent_id.nil?` and source it from the full list of 12.
Not required to unblock `bin/setup`; wants its own commit and test.
