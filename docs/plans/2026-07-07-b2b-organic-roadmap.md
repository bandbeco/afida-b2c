---
type: Plan
description: Task-by-task implementation plan executing the B2B organic growth strategy, covering 404 recovery, trade-intent retitling, and code-level SEO fixes.
status: active
timestamp: 2026-07-07
---

# B2B Organic Growth Roadmap: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Execute `docs/seo/b2b-organic-growth-plan-2026-07.md`: recover the 404-damaged rankings, re-point every commercial surface at UK trade buyers (wholesale titles, stockist lane, business-type templates), and close the code-level SEO gaps.

**Architecture:** Mostly small, independent changes across three lanes: (a) Rails code changes (routes, one migration, helpers, views), TDD with Minitest fixtures; (b) production data changes (category metas, blog CTA targets, site settings) applied via `kamal app exec` runner scripts or the admin; (c) manual external steps (GSC, Merchant Center, Vegware outreach). Each task is self-contained and committable on its own.

**Tech Stack:** Rails 8, Minitest + fixtures, Kamal deploys, Nokogiri sitemap, JSON-LD via helpers.

---

## Conventions for every task (read first)

- **Branch/commits:** commit directly to `master` (never create branches). No `Co-Authored-By` lines. Small message, imperative mood.
- **TDD applies to app code only.** Data scripts (Phase 0 Task 6, Phase 1 Task 8) are throwaway runners: no tests, but always run their DRY_RUN mode first.
- **Style rules:** no inline styles, no `font-bold`/`font-semibold` in any new markup. Match surrounding view idiom (Tailwind + daisyUI classes).
- **Run tests:** `bin/rails test <file>` for one file, `bin/rails test` for the suite.
- **Production data scripts** are transported like this (the codebase's established pattern):
  ```bash
  B64=$(base64 -i script.rb | tr -d '\n')
  kamal app exec --reuse "bash -c 'cd /rails && echo $B64 | base64 -d | bin/rails runner -'"
  ```
- **Deploys:** `kamal deploy` silently fails on this project (postgres accessory host aborts it before retagging). Deploy with:
  ```bash
  kamal app boot --version=$(git rev-parse HEAD) --roles=web
  ```
  then verify a changed URL's **served HTML** with `curl`, never trust exit codes.
- Fixtures referenced in tests below are real and already exist: `categories(:cups)`, `categories(:parent_cups_and_drinks)`, `categories(:child_hot_cups)`, `blog_posts(:published_post)`, `products(:single_wall_8oz_white)` (family `single_wall_cups`), `collection_category_guides(:vegware_cups_and_drinks)`.

---

# Phase 0: Protect the base (this week)

> **Status 2026-07-07:** DONE, with notes. Code (Tasks 2, 3, 4 and the Task 5 guide migrations) is committed on branch `seo-phase-0` awaiting review + merge + deploy. Task 6 (blog CTA targets) applied to production, 23 posts, verified live. Task 1 findings: sitemap already re-read by Google 6 Jul (754 pages, Success); new category URLs are indexed; old URLs ice-cream-cups, straws, aluminium-containers already digested as "Page with redirect" (crawled 4-6 Jul); stale old soup-containers and bagasse-containers got manual reindex requests. Remaining old URLs (pizza-boxes, hot-cups, cold-cups, takeaway-boxes, cup-lids) left to Google's active recrawl.

## Task 1: GSC housekeeping (manual, ~30 min, no code)

The 301s for the June renames went live 2026-07-02 but Google has barely recrawled: daily clicks are still ~7/day vs ~10 pre-rename, and the new ice-cream-cups URL has 34 impressions vs 7,362 on the dead one.

- [ ] **Step 1: Resubmit the sitemap.** GSC property `sc-domain:afida.com` → Sitemaps → enter `https://afida.com/sitemap.xml` → Submit (resubmitting refreshes the fetch even if already listed).
- [ ] **Step 2: Request indexing of the new category URLs** (URL Inspection → paste URL → "Request indexing"). GSC allows roughly 10/day; do them in this priority order, spill the rest to tomorrow:
  1. `https://afida.com/categories/cups-and-accessories/ice-cream-cups`
  2. `https://afida.com/categories/food-containers/soup-containers`
  3. `https://afida.com/categories/cups-and-accessories/straws`
  4. `https://afida.com/categories/food-containers/aluminium-containers`
  5. `https://afida.com/categories/cups-and-accessories/hot-cups`
  6. `https://afida.com/categories/cups-and-accessories/cold-cups-and-lids`
  7. `https://afida.com/categories/food-containers/pizza-boxes`
  8. `https://afida.com/categories/food-containers/takeaway-boxes`
  9. `https://afida.com/categories/cups-and-accessories`
  10. `https://afida.com/categories/food-containers`
- [ ] **Step 3: Inspect (do not request) the top dead URLs** to confirm Google sees the redirect. Expect "Page with redirect" for:
  - `https://afida.com/categories/cups-and-drinks/ice-cream-cups`
  - `https://afida.com/categories/hot-food/soup-containers`
  - `https://afida.com/categories/cups-and-drinks/straws`
  If any show "Not found (404)", re-check the live redirect with `curl -sI` before moving on.
- [ ] **Step 4:** Note the date in `docs/seo/backlog.md` so the ~Jul 17 measurement can separate redirect recovery from the retitle work.

## Task 2: 301s for the two still-404 vegware filter URLs (dev)

Found 2026-07-07: `/collections/vegware/cups-and-drinks` (724 imp/quarter in GSC) and `/collections/vegware/hot-food` still 404. The June redirect map only covered `/categories/*`.

**Files:**
- Modify: `config/routes.rb` (immediately after the `/categories/hot-food/*path` catch-all at ~line 102)
- Test: `test/integration/category_rename_redirects_test.rb` (existing file for the June rename redirects)

- [ ] **Step 1: Write the failing tests.** Append inside the test class:

```ruby
test "old vegware cups-and-drinks filter 301s to cups-and-accessories" do
  get "/collections/vegware/cups-and-drinks"
  assert_response :moved_permanently
  assert_redirected_to "/collections/vegware/cups-and-accessories"
end

test "old vegware hot-food filter 301s to food-containers preserving query string" do
  get "/collections/vegware/hot-food?utm_source=x"
  assert_response :moved_permanently
  assert_redirected_to "/collections/vegware/food-containers?utm_source=x"
end
```

- [ ] **Step 2: Run to verify they fail.**

Run: `bin/rails test test/integration/category_rename_redirects_test.rb`
Expected: 2 failures (routes render 404 / RecordNotFound, not a redirect).

- [ ] **Step 3: Add the routes.** In `config/routes.rb`, directly below the `get "/categories/hot-food/*path"` line:

```ruby
  # Vegware collection filter pages under the renamed category slugs (June 2026
  # renames): the /categories/* map above does not cover these.
  get "/collections/vegware/cups-and-drinks", to: redirect(status: 301) { |_params, req| "/collections/vegware/cups-and-accessories#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/collections/vegware/hot-food", to: redirect(status: 301) { |_params, req| "/collections/vegware/food-containers#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
```

- [ ] **Step 4: Run tests, verify pass.** `bin/rails test test/integration/category_rename_redirects_test.rb` → all green.
- [ ] **Step 5: Commit.**

```bash
git add config/routes.rb test/integration/category_rename_redirects_test.rb
git commit -m "Add 301s for vegware filter pages under renamed category slugs"
```

## Task 3: Category slug-history auto-redirect (dev)

Admin renames caused the June 404 incident and will recur. Persist old slugs and 301 them forever. This also subsumes the existing flat-URL and stale-parent redirects via one canonical-path check.

**Files:**
- Create: migration `db/migrate/*_create_category_slug_redirects.rb`
- Create: `app/models/category_slug_redirect.rb`
- Modify: `app/models/category.rb`
- Modify: `app/controllers/categories_controller.rb`
- Test: `test/models/category_slug_redirect_test.rb` (new), `test/controllers/categories_controller_test.rb` (extend)

- [ ] **Step 1: Generate the migration.**

```bash
bin/rails generate migration CreateCategorySlugRedirects
```

Fill the generated file with:

```ruby
class CreateCategorySlugRedirects < ActiveRecord::Migration[8.0]
  def change
    create_table :category_slug_redirects do |t|
      t.string :old_slug, null: false
      t.references :category, null: false, foreign_key: true
      t.timestamps
    end
    add_index :category_slug_redirects, :old_slug, unique: true
  end
end
```

(Keep whatever migration version number the generator emits.)

- [ ] **Step 2: Migrate.** `bin/rails db:migrate` (dev) then `bin/rails db:test:prepare`.
- [ ] **Step 3: Write the failing model tests.** Create `test/models/category_slug_redirect_test.rb`:

```ruby
require "test_helper"

class CategorySlugRedirectTest < ActiveSupport::TestCase
  test "renaming a category slug records a redirect from the old slug" do
    category = categories(:cups)
    old_slug = category.slug

    category.update!(slug: "renamed-for-slug-history-test")

    redirect = CategorySlugRedirect.find_by(old_slug: old_slug)
    assert_equal category, redirect&.category
  end

  test "reclaiming an old slug removes the stale redirect" do
    category = categories(:cups)
    original = category.slug

    category.update!(slug: "temporary-slug")
    category.update!(slug: original)

    assert_not CategorySlugRedirect.exists?(old_slug: original),
      "a redirect must never shadow a live slug"
    assert CategorySlugRedirect.exists?(old_slug: "temporary-slug", category_id: category.id)
  end

  test "re-renaming keeps a single redirect per old slug pointing at the owner" do
    a = categories(:cups)
    old_slug = a.slug
    a.update!(slug: "first-rename")
    a.update!(slug: "second-rename")

    assert_equal 1, CategorySlugRedirect.where(old_slug: old_slug).count
    assert CategorySlugRedirect.exists?(old_slug: "first-rename", category_id: a.id)
  end
end
```

- [ ] **Step 4: Run to verify failure.** `bin/rails test test/models/category_slug_redirect_test.rb` → fails (uninitialized constant / no callback).
- [ ] **Step 5: Create the model.** `app/models/category_slug_redirect.rb`:

```ruby
class CategorySlugRedirect < ApplicationRecord
  belongs_to :category

  validates :old_slug, presence: true, uniqueness: true
end
```

- [ ] **Step 6: Record history on rename.** In `app/models/category.rb`, add below the `has_many :collection_category_guides` line:

```ruby
  has_many :slug_redirects, class_name: "CategorySlugRedirect", dependent: :destroy

  after_update :record_slug_history
```

and in the `private` section:

```ruby
  # Every admin rename leaves a permanent 301 behind (the June 2026 renames
  # 404'd ~16k impressions/quarter of ranking URLs; never again).
  def record_slug_history
    return unless saved_change_to_slug?

    previous_slug = saved_change_to_slug.first
    return if previous_slug.blank?

    # A redirect must never shadow a live slug, and the latest rename wins.
    CategorySlugRedirect.where(old_slug: [ slug, previous_slug ]).destroy_all
    slug_redirects.create!(old_slug: previous_slug)
  end
```

- [ ] **Step 7: Run model tests, verify pass.** `bin/rails test test/models/category_slug_redirect_test.rb`
- [ ] **Step 8: Write the failing controller tests.** Append to `test/controllers/categories_controller_test.rb`:

```ruby
  test "renamed subcategory slug 301s to the current nested URL" do
    child = categories(:child_hot_cups)
    old_slug = child.slug
    child.update!(slug: "#{old_slug}-renamed")

    get "/categories/#{child.parent.slug}/#{old_slug}"
    assert_response :moved_permanently
    assert_redirected_to "/categories/#{child.parent.slug}/#{old_slug}-renamed"
  end

  test "renamed parent slug 301s nested child URLs to the current parent" do
    parent = categories(:parent_cups_and_drinks)
    child = categories(:child_hot_cups)
    old_parent_slug = parent.slug
    parent.update!(slug: "#{old_parent_slug}-renamed")

    get "/categories/#{old_parent_slug}/#{child.slug}"
    assert_response :moved_permanently
    assert_redirected_to "/categories/#{old_parent_slug}-renamed/#{child.slug}"
  end

  test "renamed slug redirect preserves query parameters" do
    child = categories(:child_hot_cups)
    old_slug = child.slug
    child.update!(slug: "#{old_slug}-renamed")

    get "/categories/#{child.parent.slug}/#{old_slug}?colour=white"
    assert_response :moved_permanently
    assert_redirected_to "/categories/#{child.parent.slug}/#{old_slug}-renamed?colour=white"
  end

  test "never-existing slug still 404s" do
    get category_url("never-existed-slug")
    assert_response :not_found
  end
```

- [ ] **Step 9: Run to verify failure.** `bin/rails test test/controllers/categories_controller_test.rb` → the three redirect tests fail (404 via `find_by!`).
- [ ] **Step 10: Rewrite the lookup in `app/controllers/categories_controller.rb`.** Replace the whole `show` action's lookup block (lines 4-18) with:

```ruby
  def show
    @category = Category.includes(:parent, image_attachment: :blob).find_by(slug: params[:id])
    @category ||= CategorySlugRedirect.find_by(old_slug: params[:id])&.category

    raise ActiveRecord::RecordNotFound unless @category

    # Enforce the canonical URL. One check covers: subcategories reached via
    # flat URLs, renamed child slugs, and stale parent slugs in nested URLs.
    canonical_path = helpers.category_browse_path(@category)
    if request.path != canonical_path
      target = canonical_path
      target += "?#{request.query_parameters.to_query}" if request.query_parameters.present?
      redirect_to target, status: :moved_permanently
      return
    end
```

The rest of the action (children preload, `@products`, single-product redirect) stays exactly as is. Note `@parent` is no longer assigned; the view reads `@category.parent`, so nothing else changes.

- [ ] **Step 11: Run the full categories suite.** `bin/rails test test/controllers/categories_controller_test.rb test/integration/category_routes_test.rb test/integration/category_rename_redirects_test.rb` → all green (the old flat-to-nested redirect behaviour is preserved by the canonical check).
- [ ] **Step 12: Run the whole suite once.** `bin/rails test` → green.
- [ ] **Step 13: Commit.**

```bash
git add db/migrate db/schema.rb app/models/category_slug_redirect.rb app/models/category.rb app/controllers/categories_controller.rb test/models/category_slug_redirect_test.rb test/controllers/categories_controller_test.rb
git commit -m "Auto-301 renamed category slugs via persisted slug history"
```

## Task 4: Category meta_description fallback (dev)

Categories with a blank `meta_description` ship an empty `<meta name="description">` today.

**Files:**
- Modify: `app/models/category.rb`
- Modify: `app/views/categories/show.html.erb:10`, `:22`, `:29`
- Test: `test/models/category_test.rb` (extend or create)

- [ ] **Step 1: Write the failing tests.** In `test/models/category_test.rb`:

```ruby
  test "meta_description_with_fallback prefers the explicit meta description" do
    category = categories(:cups)
    category.meta_description = "Explicit copy"
    assert_equal "Explicit copy", category.meta_description_with_fallback
  end

  test "meta_description_with_fallback falls back to description then generated copy" do
    category = categories(:cups)
    category.meta_description = ""
    category.description = "On-page description"
    assert_equal "On-page description", category.meta_description_with_fallback

    category.description = ""
    assert_includes category.meta_description_with_fallback, category.name.downcase
    assert_includes category.meta_description_with_fallback, "free UK delivery"
  end
```

- [ ] **Step 2: Run to verify failure.** `bin/rails test test/models/category_test.rb` → NoMethodError.
- [ ] **Step 3: Implement.** In `app/models/category.rb`, below `to_param`:

```ruby
  # Search-snippet description with fallbacks so no category ever ships an
  # empty <meta name="description"> tag.
  def meta_description_with_fallback
    meta_description.presence ||
      description.presence ||
      "Buy #{name.downcase} in bulk from Afida. Eco-friendly catering disposables for UK food businesses, with free UK delivery over £100."
  end
```

- [ ] **Step 4: Run tests, verify pass.** `bin/rails test test/models/category_test.rb`
- [ ] **Step 5: Use it in the view.** In `app/views/categories/show.html.erb` replace all three occurrences of `@category.meta_description` (lines 10, 22, 29) with `@category.meta_description_with_fallback`.
- [ ] **Step 6: Full-file check.** `bin/rails test test/controllers/categories_controller_test.rb test/integration/comprehensive_seo_test.rb` → green.
- [ ] **Step 7: Commit.**

```bash
git add app/models/category.rb app/views/categories/show.html.erb test/models/category_test.rb
git commit -m "Fall back to generated category meta descriptions"
```

## Task 5: Buying guides + metas for the two guideless categories (content)

`bowls-and-lids` (30 products) and `portion-pots-and-lids` (33 products) were created in the June restructure with no buying guide and no ranking history.

- [ ] **Step 1:** Run the `/buying-guide` skill for `bowls-and-lids` (it produces SEO-informed guide copy for a category).
- [ ] **Step 2:** Run the `/buying-guide` skill for `portion-pots-and-lids`.
- [ ] **Step 3:** Paste each guide into the category's `buying_guide` field in `/admin` (Categories → edit). Set `meta_title`/`meta_description` from the Task 8 table below (rows `bowls-and-lids`, `portion-pots-and-lids`) at the same time.
- [ ] **Step 4:** Verify both pages render the guide + `Article` schema: `curl -s https://afida.com/categories/food-containers/bowls-and-lids | grep -c "application/ld+json"` should report one more block than before (and the guide text should appear in the HTML).

## Task 6: Shop-CTA targets for the 23 uncovered blog posts (data)

Only 17/40 published posts drive the Move 1 "Shop our range" CTA (`target_collection_slugs` / `target_category_slugs`, jsonb arrays).

- [ ] **Step 1: Write the script** to `scratchpad/blog_cta_targets.rb`:

```ruby
# Populates Move 1 shop-CTA targets on published posts that have none.
# DRY_RUN=1 prints what would change without writing.
MAPPING = {
  "eco-friendly-packaging"                      => { cols: %w[eco-essentials], cats: %w[food-containers] },
  "recyclable-coffee-cups"                      => { cols: [], cats: %w[hot-cups cup-lids] },
  "compostable-vs-biodegradable"                => { cols: %w[eco-essentials], cats: %w[bagasse-containers] },
  "compostable-cups"                            => { cols: [], cats: %w[hot-cups cold-cups-and-lids] },
  "disposable-coffee-cups"                      => { cols: %w[coffee-shops], cats: %w[hot-cups] },
  "biodegradable-straws"                        => { cols: [], cats: %w[straws] },
  "pub-supplies"                                => { cols: %w[pubs-bars], cats: %w[napkins] },
  "takeaway-boxes"                              => { cols: %w[takeaway], cats: %w[takeaway-boxes] },
  "luxury-napkins"                              => { cols: %w[hotels], cats: %w[napkins] },
  "how-to-start-a-catering-business"            => { cols: %w[restaurants], cats: %w[food-containers] },
  "branded-greaseproof-paper"                   => { cols: [], cats: %w[greaseproof-and-wraps] },
  "custom-printed-paper-cups"                   => { cols: [], cats: %w[hot-cups] },
  "eco-straws"                                  => { cols: [], cats: %w[straws] },
  "branded-paper-cups"                          => { cols: [], cats: %w[hot-cups] },
  "food-packaging-branding"                     => { cols: [], cats: %w[food-containers-and-lids bags] },
  "compostable-food-packaging"                  => { cols: %w[eco-essentials], cats: %w[bagasse-containers] },
  "paper-bag-for-food"                          => { cols: [], cats: %w[bags] },
  "buy-custom-printed-coffee-cups-small-orders" => { cols: [], cats: %w[hot-cups] },
  "vegware-product-guide-reviews-2026"          => { cols: %w[vegware], cats: [] },
  "food-disposable-containers"                  => { cols: %w[takeaway], cats: %w[food-containers-and-lids] },
  "printing-on-greaseproof-paper"               => { cols: [], cats: %w[greaseproof-and-wraps] },
  "design-of-food-packaging"                    => { cols: [], cats: %w[takeaway-boxes bags] },
  "baking-boxes-wholesale"                      => { cols: %w[bakeries], cats: [] }
}.freeze

dry = ENV["DRY_RUN"] == "1"
MAPPING.each do |slug, t|
  post = BlogPost.find_by(slug: slug)
  next puts("MISSING  #{slug}") unless post
  next puts("SKIP     #{slug} (already has targets)") if post.target_collection_slugs.present? || post.target_category_slugs.present?

  bad_cols = t[:cols] - Collection.where(slug: t[:cols]).pluck(:slug)
  bad_cats = t[:cats] - Category.where(slug: t[:cats]).pluck(:slug)
  next puts("BADSLUG  #{slug}: #{(bad_cols + bad_cats).join(",")}") if bad_cols.any? || bad_cats.any?

  if dry
    puts "WOULD SET #{slug} -> cols=#{t[:cols].join(",")} cats=#{t[:cats].join(",")}"
  else
    post.update!(target_collection_slugs: t[:cols], target_category_slugs: t[:cats])
    puts "SET      #{slug}"
  end
end
```

- [ ] **Step 2: Dry-run against production.**

```bash
B64=$(base64 -i scratchpad/blog_cta_targets.rb | tr -d '\n')
kamal app exec --reuse "bash -c 'cd /rails && echo $B64 | base64 -d | DRY_RUN=1 bin/rails runner -'"
```

Expected: 23 `WOULD SET` lines, zero `BADSLUG`/`MISSING`. Review the mapping choices; adjust any pairing you disagree with.

- [ ] **Step 3: Apply** (same command without `DRY_RUN=1`). Expected: 23 `SET` lines.
- [ ] **Step 4: Spot-check** two posts render the CTA: `curl -s https://afida.com/blog/takeaway-boxes | grep -o "Shop our range"` → match.

---

# Phase 1: Trade-intent commercial surfaces (week of Jul 13)

## Task 7: Render the GEO question heading on category pages (dev) — DROPPED 2026-07-20

**Do not do this task.** Attempted 2026-07-20 and abandoned on evidence. `category_question_heading` is not an unrendered leftover: it was deliberately removed from the category page in March by commit `d60461d5` ("Add hero section and buying guide to category pages for SEO depth", closing #106), and that commit added a test, `"show page does not render question heading"` in `test/controllers/categories_controller_test.rb`, specifically to keep it out. Rendering it makes that test fail, so shipping this task means deleting a guard someone wrote on purpose.

The design reason still holds: the hero already displays the category name prominently, so a question heading immediately above the product grid is redundant chrome. Not worth overturning a prior decision for a speculative GEO gain. Recorded in [the audit](/seo/seo-audit-2026-07-19.md) and the [B2B plan](/seo/b2b-organic-growth-plan-2026-07.md) W1.

**Process note for the rest of this roadmap:** this task was written from a grep showing the helper had no callers. A grep proves absence of use, not absence of intent. Check `git log -S` for why something is missing before treating it as an oversight.

<details>
<summary>Original (superseded) steps</summary>

**Files:**
- Modify: `app/views/categories/show.html.erb` (between hero section and product grid)
- Test: `test/controllers/categories_controller_test.rb`

- [ ] **Step 1: Write the failing test.**

```ruby
  test "show page renders the GEO question heading" do
    get category_url(@category.slug)
    assert_response :success
    assert_select "h2", text: /does Afida offer\?/
  end
```

- [ ] **Step 2: Run to verify failure.** `bin/rails test test/controllers/categories_controller_test.rb` → 0 matching h2.
- [ ] **Step 3: Implement.** In `app/views/categories/show.html.erb`, insert between the closing `</section>` of the hero (line 80) and the `<div class="min-h-[60vh]">` grid wrapper:

```erb
<%# GEO: question-style heading that the grid and buying guide below answer %>
<h2 class="text-2xl tracking-tight mb-6"><%= category_question_heading(@category) %></h2>
```

- [ ] **Step 4: Run tests, verify pass.** `bin/rails test test/controllers/categories_controller_test.rb`
- [ ] **Step 5: Visual check** in dev (`bin/dev`, open `/categories/tableware/napkins`): the heading should read naturally between hero and grid.
- [ ] **Step 6: Commit.**

```bash
git add app/views/categories/show.html.erb test/controllers/categories_controller_test.rb
git commit -m "Render the question-style GEO heading on category pages"
```

</details>

## Task 8: Trade-intent retitle of all categories (data)

The SERP winners' pattern (trade modifier + buyer + case economics), applied to every category. This is production data; `meta_title`/`meta_description` are columns on `categories`.

- [ ] **Step 1: Write the script** to `scratchpad/category_retitle.rb`. It must print `old -> new` for every row and support `DRY_RUN=1`:

```ruby
# Trade-intent meta titles/descriptions per docs/seo/b2b-organic-growth-plan-2026-07.md W1.
# DRY_RUN=1 prints the diff without writing.
COPY = {
  "cups-and-accessories" => ["Takeaway Cups & Lids | Wholesale UK | Afida",
    "Hot cups, cold cups, lids and straws by the case. Eco-friendly cup supplies for cafés, coffee shops and takeaways. Free UK delivery over £100."],
  "food-containers" => ["Takeaway Food Containers | Wholesale UK | Afida",
    "Takeaway boxes, soup containers, bagasse and aluminium trays in bulk. Compostable food packaging for takeaways and restaurants. Free UK delivery over £100."],
  "cold-food-and-salads" => ["Salad & Deli Containers | Wholesale UK | Afida",
    "Deli pots, salad boxes and sandwich packaging by the case. Eco-friendly cold food packaging for delis and cafés. Free UK delivery over £100."],
  "tableware" => ["Eco Tableware | Napkins, Cutlery & Plates | Bulk UK | Afida",
    "Napkins, wooden cutlery, plates and bowls in bulk. Compostable tableware for restaurants, cafés and events. Free UK delivery over £100."],
  "bags-and-wraps" => ["Paper Bags & Food Wraps | Wholesale UK | Afida",
    "Kraft paper bags, greaseproof paper and NatureFlex bags by the case. Eco packaging for bakeries and takeaways. Free UK delivery over £100."],
  "supplies-and-essentials" => ["Catering Supplies & Essentials | Bulk UK | Afida",
    "Bin liners, gloves, labels and till rolls in bulk. Everyday essentials for commercial kitchens at wholesale prices. Free UK delivery over £100."],
  "hot-cups" => ["Takeaway Coffee Cups | Wholesale UK | Bulk | Afida",
    "Single wall, double wall and ripple paper coffee cups by the case. Compostable options for cafés and coffee shops. Free UK delivery over £100."],
  "cold-cups-and-lids" => ["Cold Cups & Lids | Smoothie Cups Wholesale UK | Afida",
    "Clear PLA and paper cold cups with lids for smoothies, juices and iced drinks. Bulk cases for cafés and juice bars. Free UK delivery over £100."],
  "cup-lids" => ["Coffee Cup Lids | Wholesale UK | Afida",
    "Sip lids, dome lids and compostable cup lids by the case, sized to fit our hot and cold cups. Bulk prices for cafés. Free UK delivery over £100."],
  "cup-accessories" => ["Cup Carriers, Sleeves & Stirrers | Bulk UK | Afida",
    "Cup carriers, sleeves, stirrers and clutches in bulk. Everything around the cup for busy takeaway counters. Free UK delivery over £100."],
  "ice-cream-cups" => ["Ice Cream Cups | Paper Dessert Cups | Bulk UK | Afida",
    "Paper ice cream and dessert cups for gelato and frozen yogurt, with spoons and lids. Bulk cases for parlours. Free UK delivery over £100."],
  "straws" => ["Paper & Bamboo Straws | Wholesale UK | Afida",
    "Biodegradable paper, bamboo pulp and fibre straws by the case. Plastic-free straws for bars, cafés and restaurants. Free UK delivery over £100."],
  "takeaway-boxes" => ["Takeaway Boxes | Kraft & Bagasse | Wholesale UK | Afida",
    "Kraft and bagasse takeaway boxes by the case. Leak-resistant, compostable food boxes for takeaways and street food. Free UK delivery over £100."],
  "food-containers-and-lids" => ["Food Containers with Lids | Wholesale UK | Afida",
    "Microwaveable and compostable food containers with matching lids, by the case. For takeaways, delis and meal prep. Free UK delivery over £100."],
  "soup-containers" => ["Soup Containers & Lids | Wholesale UK | Afida",
    "Paper soup containers and vented lids by the case. Leak-proof cups for soup, noodles and hot food to go. Free UK delivery over £100."],
  "bagasse-containers" => ["Bagasse Containers | Compostable | Wholesale UK | Afida",
    "Sugarcane bagasse boxes, trays and clamshells in bulk. Certified compostable and microwave-safe, for takeaways and cafés. Free UK delivery over £100."],
  "pizza-boxes" => ["Pizza Boxes | Kraft | Wholesale UK | Afida",
    "Kraft corrugated pizza boxes by the case, in sizes for every menu. Recyclable boxes for pizzerias and takeaways. Free UK delivery over £100."],
  "aluminium-containers" => ["Aluminium Foil Containers | Wholesale UK | Afida",
    "Aluminium foil food containers and lids in bulk. Oven-safe trays for takeaways, curry houses and caterers. Free UK delivery over £100."],
  "bowls-and-lids" => ["Takeaway Bowls & Lids | Wholesale UK | Afida",
    "Kraft and PLA-lined takeaway bowls with matching lids, by the case. For poke, salads, ramen and hot food to go. Free UK delivery over £100."],
  "portion-pots-and-lids" => ["Portion Pots & Lids | Sauce Pots Wholesale UK | Afida",
    "Sauce pots, dip pots and portion cups with lids, by the case. Compostable options for takeaways and delis. Free UK delivery over £100."],
  "deli-containers" => ["Deli Containers | Wholesale UK | Afida",
    "Deli pots and hinged deli containers by the case. Clear, leak-resistant packaging for delis and salad bars. Free UK delivery over £100."],
  "salad-boxes" => ["Salad Boxes & Bowls | Wholesale UK | Afida",
    "Kraft salad boxes and bowls with lids, by the case. Eco-friendly salad packaging for cafés and delis. Free UK delivery over £100."],
  "sandwich-and-wrap-boxes" => ["Sandwich & Wrap Packaging | Wholesale UK | Afida",
    "Sandwich wedges, wrap boxes and baguette packs in bulk. Compostable windows, ready for café counters. Free UK delivery over £100."],
  "cutlery" => ["Wooden & Compostable Cutlery | Wholesale UK | Afida",
    "Wooden and compostable cutlery by the case: forks, knives, spoons and sets. Plastic-free for cafés and events. Free UK delivery over £100."],
  "napkins" => ["Paper Napkins & Serviettes | Wholesale UK | Afida",
    "Paper napkins and serviettes for restaurants, cafés and hotels. Cocktail, dinner and luxury airlaid, by the case. Free UK delivery over £100."],
  "plates-and-bowls" => ["Disposable Plates & Bowls | Wholesale UK | Afida",
    "Paper and bagasse plates and bowls in bulk. Sturdy, compostable tableware for events and street food. Free UK delivery over £100."],
  "bags" => ["Paper Bags | Kraft & Handled | Wholesale UK | Afida",
    "Kraft paper bags with and without handles, by the case. Takeaway and bakery bags in every size. Free UK delivery over £100."],
  "greaseproof-and-wraps" => ["Greaseproof Paper & Wraps | Wholesale UK | Afida",
    "Greaseproof sheets, deli wraps and burger wraps in bulk. Food-safe papers for kitchens and counters. Free UK delivery over £100."],
  "natureflex-bags" => ["NatureFlex Bags | Compostable Cello Bags UK | Afida",
    "Certified home-compostable NatureFlex bags by the case. Clear cello-style bags for bakery and confectionery. Free UK delivery over £100."],
  "bin-liners" => ["Compostable Bin Liners | Wholesale UK | Afida",
    "Compostable bin liners in catering sizes, by the case. For food waste and general kitchen use. Free UK delivery over £100."],
  "gloves-and-cleaning" => ["Catering Gloves & Cleaning Supplies | Bulk UK | Afida",
    "Food-safe gloves and kitchen cleaning essentials in bulk for commercial kitchens. Free UK delivery over £100."],
  "labels-and-stickers" => ["Food Labels & Day Dots | Wholesale UK | Afida",
    "Day dot labels, allergen labels and food rotation sets by the case. Kitchen compliance made easy. Free UK delivery over £100."],
  "till-rolls" => ["Till Rolls | Thermal Receipt Rolls | Bulk UK | Afida",
    "Thermal till rolls and receipt paper in bulk for cafés, shops and restaurants. Free UK delivery over £100."]
}.freeze

dry = ENV["DRY_RUN"] == "1"
COPY.each do |slug, (title, desc)|
  category = Category.find_by(slug: slug)
  next puts("MISSING #{slug}") unless category

  puts "#{slug}:"
  puts "  title: #{category.meta_title.inspect} -> #{title.inspect}"
  puts "  desc:  #{category.meta_description.to_s.truncate(60).inspect} -> #{desc.truncate(60).inspect}"
  category.update!(meta_title: title, meta_description: desc) unless dry
end
```

- [ ] **Step 2: Dry-run against production** (same base64 transport as Task 6, with `DRY_RUN=1`). Read every `old -> new` line: where an existing hand-tuned title is clearly better on a specific row, edit that row before applying. Note: the Task 3 slug-history code must be deployed first if any slug edits sneak in here; this script only touches meta fields, not slugs.
- [ ] **Step 3: Apply** without `DRY_RUN`.
- [ ] **Step 4: Verify live.** `curl -s https://afida.com/categories/food-containers/soup-containers | grep -o "<title>[^<]*</title>"` → `Soup Containers & Lids | Wholesale UK | Afida`.
- [ ] **Step 5:** Record the ship date in `docs/seo/backlog.md` (needed to read the position deltas at the next GSC pull).

## Task 9: Internal links to business-type collections (dev)

Collections earn ~zero organic visits partly because almost nothing links to them.

**Files:**
- Modify: `app/views/shared/_footer.html.erb` (new nav column)
- Test: `test/integration/footer_test.rb` (existing)

- [ ] **Step 1: Write the failing test.** Append to `test/integration/footer_test.rb`:

```ruby
  test "footer links the business-type collections" do
    get root_url
    assert_select "footer a[href=?]", "/collections/restaurants"
    assert_select "footer a[href=?]", "/collections/coffee-shops"
    assert_select "footer a[href=?]", "/collections/vegware", text: /Vegware/
  end
```

- [ ] **Step 2: Run to verify failure.** `bin/rails test test/integration/footer_test.rb`
- [ ] **Step 3: Implement.** In `app/views/shared/_footer.html.erb`, after the "Shop by Category" `</nav>`, add:

```erb
      <nav aria-labelledby="footer-business-types">
        <span id="footer-business-types" class="footer-title">Shop by Business</span>
        <% Collection.regular.where(slug: %w[restaurants coffee-shops bakeries ice-cream-parlours pubs-bars hotels smoothie-juice-bars takeaway eco-essentials]).order(:name).each do |collection| %>
          <%= link_to collection.name, collection_path(collection), class: "link link-hover" %>
        <% end %>
        <%= link_to "Vegware (Official Stockist)", collection_path("vegware"), class: "link link-hover" %>
      </nav>
```

(If `Collection.regular` is not the scope name in `app/models/collection.rb`, check the model; the collections controller uses `Collection.regular.find_by!` so it exists.)

- [ ] **Step 4: Run tests, verify pass.** `bin/rails test test/integration/footer_test.rb`
- [ ] **Step 5: Commit.**

```bash
git add app/views/shared/_footer.html.erb test/integration/footer_test.rb
git commit -m "Link business-type collections and Vegware stockist from the footer"
```

## Phase 1 deploy

- [ ] `kamal app boot --version=$(git rev-parse HEAD) --roles=web`
- [ ] Verify served HTML: `curl -s https://afida.com/categories/tableware/napkins | grep -o "does Afida offer?"` → match; `curl -s https://afida.com/ | grep -o "Shop by Business"` → match.

---

# Phase 2: Measurement gate (~Jul 17)

## Task 10: GSC checkpoint (manual + analysis, no code)

- [ ] **Step 1:** Export GSC performance (last 3 months, Web) or re-auth the Windsor.ai MCP; drop the zip next to the previous one.
- [ ] **Step 2:** Compare against the 2026-07-07 baselines (Appendix A): 404-recovery (daily clicks vs ~10/day pre-rename), Move 1/Move 2 reads per `docs/seo/backlog.md` B1 decision rule, and the four high-intent bucket click counts.
- [ ] **Step 3: Apply the gates.**
  - Business-type buying guides (Phase 4 Task 20): GO only if `/collections/coffee-shops` or `/collections/restaurants` gained clicks and ≥3 positions vs the May baseline.
  - Variant canonicalisation (out of scope here, plan W6 Phase B): GO only if query-level data shows sibling product URLs swapping positions on one query.
- [ ] **Step 4:** Update `docs/seo/backlog.md` with the reads and re-order remaining phases if the data disagrees with this roadmap.

---

# Phase 3: Stockist lane, schema, hygiene (weeks of Jul 20-27)

## Task 11: Consolidate /vegware into /collections/vegware (dev)

Two pages compete for the vegware brand terms; the collection ranks 9 positions better. Kill the split.

**Files:**
- Modify: `config/routes.rb:119` (replace the page route with a 301)
- Modify: `app/views/shared/_vegware_stockist_banner.html.erb:11` (`vegware_path` → collection path)
- Delete: `app/views/pages/vegware.html.erb`, the `vegware` action in `app/controllers/pages_controller.rb:93-97`
- Test: `test/integration/vegware_stockist_banner_test.rb` (existing), plus a redirect test in `test/integration/legacy_redirects_test.rb`

- [ ] **Step 1: Write the failing redirect test.** Append to `test/integration/legacy_redirects_test.rb`:

```ruby
  test "vegware landing page 301s to the vegware collection" do
    get "/vegware"
    assert_response :moved_permanently
    assert_redirected_to "/collections/vegware"
  end
```

- [ ] **Step 2: Run to verify failure.** `bin/rails test test/integration/legacy_redirects_test.rb` → renders 200, not a redirect.
- [ ] **Step 3: Replace the route.** In `config/routes.rb` line 119:

```ruby
  # /vegware split brand-term rankings with /collections/vegware; one URL now
  # accumulates all the "vegware stockist" signals.
  get "vegware", to: redirect(status: 301) { |_params, req| "/collections/vegware#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
```

- [ ] **Step 4: Fix the banner link.** In `app/views/shared/_vegware_stockist_banner.html.erb` line 11 replace `vegware_path` with `collection_path("vegware")`.
- [ ] **Step 5: Delete the dead page.** Remove `app/views/pages/vegware.html.erb` and the `vegware` action (and its instance variables) from `app/controllers/pages_controller.rb`. Grep for leftovers: `grep -rn "vegware_path\|vegware_url\|pages#vegware" app test config` → only the new redirect route should remain.
- [ ] **Step 6: Run the affected suites.** `bin/rails test test/integration/legacy_redirects_test.rb test/integration/vegware_stockist_banner_test.rb test/integration/vegware_collection_test.rb test/controllers/pages_controller_test.rb` → green (update any pages_controller test that asserted 200 on /vegware to expect the 301 instead).
- [ ] **Step 7: Commit.**

```bash
git add config/routes.rb app/views/shared/_vegware_stockist_banner.html.erb app/controllers/pages_controller.rb test/
git rm app/views/pages/vegware.html.erb
git commit -m "301 /vegware into /collections/vegware to end the brand-term split"
```

## Task 12: Vegware filter pages into the sitemap (dev)

**Files:**
- Modify: `app/services/sitemap_generator_service.rb` (after the collections block, line ~72)
- Test: `test/services/sitemap_generator_service_test.rb` (create if absent)

- [ ] **Step 1: Write the failing test.**

```ruby
require "test_helper"

class SitemapGeneratorServiceTest < ActiveSupport::TestCase
  test "includes vegware category filter pages that have curated guides" do
    guide = collection_category_guides(:vegware_cups_and_drinks)
    xml = SitemapGeneratorService.new.generate

    assert_includes xml, "/collections/#{guide.collection.slug}/#{guide.category.slug}"
  end
end
```

- [ ] **Step 2: Run to verify failure.** `bin/rails test test/services/sitemap_generator_service_test.rb`
- [ ] **Step 3: Implement.** In `app/services/sitemap_generator_service.rb`, after the regular-collections `find_each` block:

```ruby
        # Vegware per-category filter pages: indexable, curated buying-guide
        # content, but previously undiscoverable via the sitemap.
        vegware = Collection.find_by(slug: "vegware")
        if vegware
          CollectionCategoryGuide.where(collection: vegware).includes(:category).find_each do |guide|
            add_url(xml, category_filter_collection_url(vegware.slug, guide.category.slug),
                    priority: "0.6",
                    changefreq: "weekly",
                    lastmod: guide.updated_at)
          end
        end
```

- [ ] **Step 4: Run tests, verify pass.** `bin/rails test test/services/sitemap_generator_service_test.rb`
- [ ] **Step 5: Commit.**

```bash
git add app/services/sitemap_generator_service.rb test/services/sitemap_generator_service_test.rb
git commit -m "Add vegware category filter pages to the sitemap"
```

## Task 13: ProductGroup / isVariantOf structured data (dev)

649 products across 137 families are indexed as unrelated near-duplicates. Phase A of the variant fix: tell Google they are one group. (Phase B, canonicalisation, is gated on Task 10 evidence and is deliberately NOT in this roadmap.)

**Files:**
- Modify: `app/helpers/seo_helper.rb` (new helper + one insertion in `product_structured_data`)
- Modify: `app/views/products/show.html.erb` (render the group script after the existing Product schema block, ~line 61)
- Test: `test/helpers/seo_helper_test.rb`

- [ ] **Step 1: Write the failing tests.** Append to `test/helpers/seo_helper_test.rb`:

```ruby
  test "product_group_structured_data emits a ProductGroup with all active family variants" do
    product = products(:single_wall_8oz_white)
    html = product_group_structured_data(product)

    assert_includes html, '"@type":"ProductGroup"'
    product.product_family.products.active.each do |variant|
      assert_includes html, product_url(variant)
    end
  end

  test "product_group_structured_data is nil without a family of 2+ products" do
    assert_nil product_group_structured_data(products(:one))
  end

  test "product_structured_data links variants to their group via isVariantOf" do
    product = products(:single_wall_8oz_white)
    json = JSON.parse(product_structured_data(product))

    assert_equal "ProductGroup", json.dig("isVariantOf", "@type")
    assert_includes json.dig("isVariantOf", "@id"), "product-family-#{product.product_family_id}"
  end
```

(If `products(:one)` has a `product_family` in fixtures, use a fixture without one; check `test/fixtures/products.yml`.)

- [ ] **Step 2: Run to verify failure.** `bin/rails test test/helpers/seo_helper_test.rb`
- [ ] **Step 3: Implement the helper.** In `app/helpers/seo_helper.rb`, add above `canonical_url`:

```ruby
  # ProductGroup schema linking size/colour variants of one family, so Google
  # groups the variant URLs instead of ranking them as competing duplicates.
  def product_group_structured_data(product)
    family = product.product_family
    return nil unless family

    variants = family.products.active.order(:id)
    return nil if variants.size < 2

    data = {
      "@context": "https://schema.org/",
      "@type": "ProductGroup",
      "@id": product_family_schema_id(family),
      "name": family.name,
      "url": product_url(variants.first),
      "brand": { "@type": "Brand", "name": "Afida" },
      "hasVariant": variants.map do |variant|
        {
          "@type": "Product",
          "name": variant.generated_title,
          "url": product_url(variant),
          "sku": variant.sku
        }.compact
      end
    }

    content_tag(:script, data.to_json.html_safe, type: "application/ld+json")
  end

  def product_family_schema_id(family)
    "#{root_url}#product-family-#{family.id}"
  end
```

- [ ] **Step 4: Link each variant to the group.** In `product_structured_data`, directly after the base `data = { ... }` hash (after the `"offers": offers` line closes it, before the `if product.product_photo.attached?` image block), insert:

```ruby
    # Ties this variant page to its ProductGroup (see product_group_structured_data)
    if product.product_family_id.present?
      data[:isVariantOf] = {
        "@type": "ProductGroup",
        "@id": product_family_schema_id(product.product_family)
      }
    end
```

- [ ] **Step 5: Run tests, verify pass.** `bin/rails test test/helpers/seo_helper_test.rb`
- [ ] **Step 6: Render on the product page.** In `app/views/products/show.html.erb`, after the existing Product JSON-LD script block (around line 61), add:

```erb
<%= product_group_structured_data(@product) %>
```

- [ ] **Step 7: Run product page suites.** `bin/rails test test/integration/variant_seo_test.rb test/integration/product_meta_tags_test.rb test/integration/comprehensive_seo_test.rb` → green.
- [ ] **Step 8: Validate one live page** after Phase 3 deploy with Google's Rich Results Test on a hot-cup variant URL.
- [ ] **Step 9: Commit.**

```bash
git add app/helpers/seo_helper.rb app/views/products/show.html.erb test/helpers/seo_helper_test.rb
git commit -m "Emit ProductGroup/isVariantOf schema for product families"
```

## Task 14: noindex the search page (dev)

**Files:**
- Modify: `app/controllers/search_controller.rb` (in `index`)
- Test: `test/controllers/search_controller_test.rb` (extend or create)

- [ ] **Step 1: Write the failing test.**

```ruby
  test "search responses carry a noindex header" do
    get search_url(q: "cups")
    assert_response :success
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
  end
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement.** First line of `SearchController#index` (mirrors `products#quick_add`):

```ruby
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
```

- [ ] **Step 4: Run tests, verify pass.**
- [ ] **Step 5: Commit.**

```bash
git add app/controllers/search_controller.rb test/controllers/search_controller_test.rb
git commit -m "Mark search results pages noindex"
```

## Task 15: Deduplicate the canonical tag (dev)

The layout always emits a default canonical (`application.html.erb:39`) AND pages like blog posts emit their own inside `content_for :head` (blog show line 5), producing two canonical tags.

**Files:**
- Modify: `app/views/layouts/application.html.erb:39`
- Modify: `app/views/blog_posts/show.html.erb:5`, `app/views/collections/show.html.erb` (its `canonical_url(...)` line, ~26), `app/views/collections/category_filter.html.erb` (~22)
- Test: `test/integration/comprehensive_seo_test.rb`

- [ ] **Step 1: Write the failing test.**

```ruby
  test "blog posts emit exactly one canonical tag" do
    get blog_post_url(blog_posts(:published_post).slug)
    assert_response :success
    assert_equal 1, response.body.scan('rel="canonical"').count
  end
```

- [ ] **Step 2: Run to verify failure.** Expected: count is 2.
- [ ] **Step 3: Centralise.** In the layout, replace line 39 with:

```erb
    <%= canonical_url(content_for(:canonical_override).presence) %>
```

Then in each of the three views, delete the inline `<%= canonical_url(...) %>` line from the `:head` block and add at the top of the file (with the other `content_for` lines):

```erb
<% content_for :canonical_override, blog_post_url(@blog_post) %>
```

(collections show: `collection_url(@collection.slug)`; category_filter: keep whatever URL that view currently passes to `canonical_url`, moved into the `content_for`.)

- [ ] **Step 4: Run.** `bin/rails test test/integration/comprehensive_seo_test.rb test/controllers/blog_posts_controller_test.rb test/controllers/collections_controller_test.rb` → green, one canonical each.
- [ ] **Step 5: Commit.**

```bash
git add app/views/layouts/application.html.erb app/views/blog_posts/show.html.erb app/views/collections/ test/integration/comprehensive_seo_test.rb
git commit -m "Emit a single canonical tag via a layout-level override"
```

## Task 16: Cache the sitemap (dev)

**Files:**
- Modify: `app/controllers/sitemaps_controller.rb`
- Test: `test/controllers/sitemaps_controller_test.rb` (extend if present, else skip test and rely on existing coverage; this is a wrapping change)

- [ ] **Step 1: Implement.** Replace the `show` action body:

```ruby
  def show
    @sitemap_xml = Rails.cache.fetch("sitemap-xml", expires_in: 6.hours) do
      SitemapGeneratorService.new.generate
    end

    respond_to do |format|
      format.xml { render xml: @sitemap_xml }
    end
  end
```

- [ ] **Step 2: Run.** `bin/rails test test/controllers/sitemaps_controller_test.rb` (or the full suite if that file doesn't exist).
- [ ] **Step 3: Standardise JSON-LD image URLs.** Attachment images inside structured data should use the stable proxy URL, not the redirecting `url_for`. Find the offenders:

```bash
grep -n "url_for(" app/helpers/seo_helper.rb app/helpers/collections_helper.rb app/views/branded_products/show.html.erb
```

For each hit where the argument is an Active Storage attachment inside a JSON-LD hash (there are hits in `seo_helper.rb` blog/category schema, `collections_helper.rb` collection/sample-pack schema, and the branded product view), replace `url_for(<attachment>)` with `rails_storage_proxy_url(<attachment>)`. Leave any non-attachment `url_for` calls alone.

- [ ] **Step 4: Run the SEO suites.** `bin/rails test test/integration/comprehensive_seo_test.rb test/helpers/seo_helper_test.rb test/helpers/collections_helper_test.rb` → green.
- [ ] **Step 5: Commit.**

```bash
git add app/controllers/sitemaps_controller.rb app/helpers/seo_helper.rb app/helpers/collections_helper.rb app/views/branded_products/show.html.erb
git commit -m "Cache the sitemap and use proxy URLs for structured-data images"
```

## Task 17: Admin content pass: vegware FAQ, napkins-for-restaurants capture, hero copy (data, admin)

- [ ] **Step 1:** In `/admin`, edit the `vegware` collection FAQs and add:
  - Q: "Where can I buy Vegware in the UK?" / A: "Afida is an official UK Vegware stockist. You can order the full Vegware range here by the case: PLA cold cups, hot cups, bagasse containers, cutlery and NatureFlex bags, with next-day delivery and free UK delivery over £100."
  - Q: "Is Afida an official Vegware stockist?" / A: "Yes. Afida stocks genuine Vegware products sourced through Vegware's UK distribution, covering over 300 Vegware lines."
- [ ] **Step 2: Napkins page-1 capture** (`napkins for restaurants` pos 9.7 and `paper napkins for restaurants` pos 6.7 currently rank via the blog guide and win 0 clicks). In `/admin`, on the `napkins` category:
  - Add to the buying guide a short "Napkins for restaurants and cafés" section (which grades of napkin suit table service vs counter service, cocktail vs dinner sizes, airlaid for hotels; two or three honest paragraphs).
  - Add FAQ: Q: "What napkins do restaurants usually use?" / A: "Most UK restaurants run 2-ply dinner napkins for table service and 1-ply cocktail napkins at the bar or counter. Hotels and premium venues use airlaid (linen-feel) napkins. All of ours ship by the case with free UK delivery over £100."
- [ ] **Step 3:** Edit `/blog/paper-napkins` in admin so the first screen links to the category: add a line to the intro along the lines of "Buying for a restaurant or café? Shop paper napkins and serviettes by the case." with the link pointing to `/categories/tableware/napkins`.
- [ ] **Step 4:** In `/admin` site settings, set the hero title to a keyword-bearing H1. Recommended: line 1 `Eco-Friendly Packaging Supplies`, line 2 `For UK Food Businesses`. Note: the current animated marquee line is a brand-voice choice; agree it with Tariq before changing, or keep line 1 keyword-bearing and leave the playful copy in line 2.
- [ ] **Step 5:** Verify: `curl -s https://afida.com/collections/vegware | grep -c "official"` ≥ 1, and the napkins category page renders the new FAQ.

## Task 18: Merchant feed coverage audit (data + Merchant Center)

Merchant listings convert at 26.7% CTR off only 116 impressions; coverage is the constraint.

- [ ] **Step 1: Run the audit** (read-only runner via the usual transport):

```ruby
active = Product.active
puts "active products:        #{active.count}"
puts "missing GTIN:           #{active.where(gtin: [ nil, "" ]).count}"
puts "missing photo:          #{active.left_joins(:product_photo_attachment).where(active_storage_attachments: { id: nil }).count}"
puts "zero/blank price:       #{active.where(price: [ nil, 0 ]).count}"
```

- [ ] **Step 2:** In Google Merchant Center, check Products → Diagnostics: how many of the 649 active products are approved for free listings? Note every disapproval reason.
- [ ] **Step 3:** Fix the top disapproval class (usually missing GTIN or image) via admin data entry; re-check diagnostics after 48h.
- [ ] **Step 4:** Record approved-product count in the KPI table (Appendix A) as the baseline.

## Task 19: Vegware stockist backlink ask (manual, outreach)

- [ ] **Step 1:** Find Vegware's UK stockist/distributor listing process (vegware.com → "where to buy"/contact, or via the distributor account manager).
- [ ] **Step 2:** Send the ask (from Laurent or Tariq, whoever owns the Vegware relationship):

> Subject: Afida.com stockist listing
>
> Hi, Afida (afida.com) stocks 300+ Vegware lines for UK cafés and restaurants, ordered by the case with next-day delivery. Could we be added to your UK stockist/where-to-buy listings? Happy to provide anything you need to verify us as a stockist. Our Vegware range: https://afida.com/collections/vegware

- [ ] **Step 3:** Log the outcome in `docs/seo/backlog.md`.

## Phase 3 deploy

- [ ] `kamal app boot --version=$(git rev-parse HEAD) --roles=web`
- [ ] Verify: `curl -sI https://afida.com/vegware | grep -i "location"` → `/collections/vegware`; `curl -s https://afida.com/sitemap.xml | grep -c "collections/vegware/"` ≥ 1; Rich Results Test on one variant product URL shows ProductGroup.
- [ ] GSC: request indexing for `https://afida.com/collections/vegware` (it just absorbed /vegware's equity).

---

# Phase 4: August (partially gated on Task 10)

## Task 20: Business-type buying guides, batch 2 (content, GATED)

Only if Task 10's gate passed. Priority order from the backlog: `eco-essentials`, then `ice-cream-parlours`, then `bakeries`.

- [ ] **Step 1:** Run `/buying-guide` per collection, paste into admin (`buying_guide` + FAQs + meta per the Move 2 pattern in `docs/seo/move2-content-draft.md`).
- [ ] **Step 2:** Add reciprocal blog links (full backlog B0b list): `/collections/ice-cream-parlours` ↔ `/blog/paper-ice-cream-cups-sizes-materials-buying-guide` and `/blog/milkshake-cups`; `/collections/coffee-shops` → `/blog/startup-costs-for-coffee-shop`, `/blog/how-to-start-coffee-shop`, `/blog/takeaway-coffee-cups`; `/collections/restaurants` → `/blog/how-to-start-a-catering-business`, `/blog/sustainable-food-packaging`. (Blog → collection direction is already handled by the Task 6 CTA targets.)
- [ ] **Step 3:** Ship one collection per week; measure at the next 4-weekly pull before doing the next.

## Task 21: Blog links to products (dev)

`target_product_slugs` (jsonb, populated column) is ignored by the CTA helper.

**Files:**
- Modify: `app/helpers/article_helper.rb:53-56` and its private section
- Test: `test/helpers/article_helper_test.rb`

- [ ] **Step 1: Write the failing test.** Append to `test/helpers/article_helper_test.rb`:

```ruby
  test "blog_post_shop_links resolves product slugs after collections and categories" do
    post = blog_posts(:published_post)
    product = products(:single_wall_8oz_white)
    post.target_product_slugs = [ product.slug ]

    links = blog_post_shop_links(post)

    assert_includes links, { name: product.generated_title, path: "/products/#{product.slug}" }
  end

  test "blog_post_shop_links drops inactive and unknown product slugs" do
    post = blog_posts(:published_post)
    post.target_product_slugs = [ products(:inactive_product).slug, "does-not-exist" ]

    assert_empty blog_post_shop_links(post).select { |l| l[:path].start_with?("/products/") }
  end
```

- [ ] **Step 2: Run to verify failure.** `bin/rails test test/helpers/article_helper_test.rb`
- [ ] **Step 3: Implement.** In `app/helpers/article_helper.rb` replace `blog_post_shop_links` with:

```ruby
  def blog_post_shop_links(blog_post)
    collection_links(blog_post.target_collection_slugs) +
      category_links(blog_post.target_category_slugs) +
      product_links(blog_post.target_product_slugs)
  end
```

and add to the private section, below `category_links`:

```ruby
  # Resolve product slugs to { name, path } hashes, preserving slug order.
  # Inactive products are dropped so the CTA never links to a 404.
  def product_links(slugs)
    return [] if slugs.blank?

    by_slug = Product.active.where(slug: slugs).index_by(&:slug)
    slugs.filter_map do |slug|
      product = by_slug[slug]
      next unless product

      { name: product.generated_title, path: product_path(product) }
    end
  end
```

- [ ] **Step 4: Run tests, verify pass.** `bin/rails test test/helpers/article_helper_test.rb`
- [ ] **Step 5: Commit.**

```bash
git add app/helpers/article_helper.rb test/helpers/article_helper_test.rb
git commit -m "Resolve target product slugs in the blog shop CTA"
```

- [ ] **Step 6 (data):** Populate `target_product_slugs` where a post reviews a specific product (e.g. `buy-custom-printed-coffee-cups-small-orders` → the double-wall branded cup product slug) via admin.

## Task 22: Custom-print cluster metas (data, admin)

The SERPs for cups terms are half custom-print intent; the low-MOQ angle is Afida's differentiator.

- [ ] **Step 1:** In `/admin`, set metas on the branded-products surface:
  - `/branding` page: title `Custom Printed Packaging | Low Minimum Orders UK | Afida`, description `Custom printed cups, bags and packaging for UK cafés and restaurants. Low minimum orders, free design check, eco-friendly stock. Free UK delivery over £100.`
  - Each `/branded-products/:slug` template: title pattern `Custom Printed [Product] | Low MOQ UK | Afida` (e.g. `Custom Printed Double Wall Cups | Low MOQ UK | Afida`).
- [ ] **Step 2:** Add a visible MOQ + lead-time line near the top of each branded product page if the data exists in admin fields; if it requires code, raise it as its own small task rather than bolting it on here.
- [ ] **Step 3:** Cross-link: from `hot-cups`, `ice-cream-cups`, `bags`, `greaseproof-and-wraps` category descriptions (admin field), add one sentence: "Need these printed with your logo? See our custom printed range." linking to `/branding`. (The description field renders as plain text in the hero; if links aren't supported there, put the link in the buying guide markdown instead.)

## Task 23: Outrank decision (manual, with Tariq)

82 drafts and climbing; the auto-import has no approval gate.

- [ ] **Step 1:** Pull the Outrank invoice/plan cost.
- [ ] **Step 2:** Count on-brand publishable drafts in the current 82 (rubric from backlog B3: maps to an existing product/category AND doesn't duplicate a published post).
- [ ] **Step 3:** Decide with Tariq: keep with a human-approval gate, downgrade, or cancel. The plan's stance: no new informational content has earned its keep; default to pause unless the drafts contain commercial-intent pieces.
- [ ] **Step 4:** Whatever the decision, triage the 82 drafts in one pass (publish the few on-brand ones with CTA targets set, delete the rest) and record the decision in `docs/seo/backlog.md`.

---

# Appendix A: KPI baselines (2026-07-07 GSC export, last 3 months)

Track clicks and fixed-term positions only; impressions are polluted by AI fan-out queries (~18.6k imp / 7 clicks this quarter).

| KPI | Baseline (to 2026-07-05) | 90-day success |
|---|---|---|
| Daily clicks (all) | ~6.9/day (post-404), ~10/day pre-rename | back above 10, then compounding |
| Wholesale bucket clicks | 0 (3,214 imp / 65 queries) | 30+ clicks/quarter across all four buckets |
| Vegware/NatureFlex bucket clicks | 0 (3,067 imp / 25 queries) | ↑ |
| "for business type" bucket clicks | 4 (1,107 imp) | ↑ |
| Custom/branded bucket clicks | 1 (621 imp) | ↑ |
| Merchant listings | 31 clicks / 26.7% CTR / 116 imp | impressions up with feed coverage, CTR held |
| Non-brand share of clicks | 46% | ≥55% |

Fixed position term set (re-check each pull):

| Term | Pos 2026-07-07 |
|---|---|
| ice cream cups | 11.6 |
| natureflex bags | 11.8 |
| vegware | 23.3 |
| vegware cups | 19.7 |
| sustainable food packaging | 12.9 |
| eco friendly food packaging | 23.3 |
| napkins for restaurants | 9.7 |
| paper napkins for restaurants | 6.7 |
| sustainable packaging for restaurants | 2.8 |
| takeaway packaging suppliers | 18.7 |
| branded smoothie cups | 9.2 |

# Appendix B: Explicitly out of scope (do not implement from this roadmap)

- Variant canonicalisation / family hero URLs (plan W6 Phase B): needs query-level cannibalisation evidence from Task 10 first.
- New informational blog posts, `/collections/takeaway` head-term content, international/hreflang work, buying guides beyond the gated batch 2.
- Retiring the dormant `UrlRedirect` middleware: harmless; revisit only if it confuses someone.
- The "Greenwash or Not?" linkable tool (backlog B6): separate build decision after the Jul 17 gate.
