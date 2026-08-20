require "test_helper"
require "csv"

# Guards the seed data files against taxonomy drift.
#
# `bin/rails db:prepare` on a fresh database loads db/schema.rb and runs seeds —
# it never runs migrations. So db/migrate/20260306204621_create_category_hierarchy.rb
# (which built the nested taxonomy) does NOT execute for a new developer, and the
# seed CSVs must therefore describe the CURRENT taxonomy on their own rather than
# the flat pre-migration state they were originally written as.
#
# These assertions are pure file/constant checks, so this inherits Minitest::Test
# rather than ActiveSupport::TestCase: no database, no fixtures, no records.
class SeedDataTest < Minitest::Test
  extend ActiveSupport::Testing::Declarative

  CATEGORIES_CSV = Rails.root.join("lib", "data", "categories.csv")
  PRODUCTS_CSV = Rails.root.join("lib", "data", "products.csv")

  # Slugs that config/routes.rb 301s at the single-segment /categories/:slug path.
  # Parsed from the routes file so this test cannot drift from it.
  ROUTE_REDIRECTED_SLUGS = Rails.root.join("config", "routes.rb").read
    .scan(%r{^\s*get\s+"/categories/([a-z0-9-]+)",\s+to:\s+redirect}).flatten.freeze

  def category_rows
    @category_rows ||= CSV.read(CATEGORIES_CSV, headers: true).map(&:to_h)
  end

  def category_slugs
    @category_slugs ||= category_rows.map { |r| r["slug"] }
  end

  def parent_rows
    category_rows.select { |r| r["parent_slug"].blank? }
  end

  def child_rows
    category_rows.reject { |r| r["parent_slug"].blank? }
  end

  # === Structure =========================================================

  test "categories.csv has a parent_slug column" do
    assert_includes CSV.read(CATEGORIES_CSV, headers: true).headers, "parent_slug",
      "categories.csv cannot express the nested taxonomy without a parent_slug column"
  end

  test "every category row has a name and a slug" do
    category_rows.each do |row|
      assert row["name"].present?, "row #{row.inspect} is missing a name"
      assert row["slug"].present?, "row #{row.inspect} is missing a slug"
    end
  end

  test "category slugs are unique" do
    duplicates = category_slugs.tally.select { |_slug, count| count > 1 }.keys
    assert_empty duplicates, "duplicate slugs in categories.csv: #{duplicates.join(', ')}"
  end

  test "every parent_slug resolves to a top-level row" do
    top_level = parent_rows.map { |r| r["slug"] }

    child_rows.each do |row|
      assert_includes top_level, row["parent_slug"],
        "#{row['slug']} names parent #{row['parent_slug'].inspect}, which is not a top-level row"
    end
  end

  test "taxonomy is 6 parents and 27 subcategories" do
    assert_equal 6, parent_rows.size, "expected 6 top-level categories"
    assert_equal 27, child_rows.size, "expected 27 subcategories"
  end

  # Titles shipped to production on 2026-07-20 and live-verified there
  # (docs/seo/category-retitles-2026-07-20.md). These five rows inherit their
  # copy from a flat category that the June restructure renamed, so it is easy
  # to reintroduce the pre-retitle value the W1 pass superseded.
  RETITLED_2026_07_20 = {
    "hot-cups"         => "Takeaway Coffee Cups & Lids | Wholesale UK | Afida",
    "straws"           => "Paper Straws | Wholesale UK | Bubble Tea & Slush | Afida",
    "bags"             => "Paper Carrier Bags | Flat & Twisted Handle | Bulk UK | Afida",
    "plates-and-bowls" => "Disposable Plates & Bowls | Bagasse, Catering Bulk | Afida",
    "cutlery"          => "Wooden Cutlery | Birchwood Forks, Knives & Spoons | Afida"
  }.freeze

  test "ported meta titles are the shipped retitles, not their superseded predecessors" do
    RETITLED_2026_07_20.each do |slug, expected|
      row = category_rows.find { |r| r["slug"] == slug }
      assert row, "categories.csv has no #{slug} row"
      assert_equal expected, row["meta_title"],
        "#{slug} carries a meta_title the 2026-07-20 retitle superseded"
    end
  end

  # The live taxonomy, read from https://afida.com/sitemap.xml on 2026-08-20.
  # This is the authority the CSV is reconstructed against — production, not the
  # March hierarchy migration, which is now out of date (it put
  # aluminium-containers under tableware; production has it under
  # food-containers).
  LIVE_TAXONOMY = {
    "bags-and-wraps" => %w[bags greaseproof-and-wraps natureflex-bags],
    "cold-food-and-salads" => %w[deli-containers salad-boxes sandwich-and-wrap-boxes],
    "cups-and-accessories" => %w[cold-cups-and-lids cup-accessories hot-cup-lids hot-cups ice-cream-cups straws],
    "food-containers" => %w[aluminium-containers bagasse-containers bowls-and-lids food-containers-and-lids
                            pizza-boxes portion-pots-and-lids soup-containers takeaway-boxes],
    "supplies-and-essentials" => %w[bin-liners gloves-and-cleaning labels-and-stickers till-rolls],
    "tableware" => %w[cutlery napkins plates-and-bowls]
  }.freeze

  test "categories.csv matches the live production taxonomy" do
    seeded = category_rows.reject { |r| r["parent_slug"].blank? }
      .group_by { |r| r["parent_slug"] }
      .transform_values { |rows| rows.map { |r| r["slug"] }.sort }

    assert_equal LIVE_TAXONOMY.keys.sort, parent_rows.map { |r| r["slug"] }.sort
    LIVE_TAXONOMY.each do |parent, children|
      assert_equal children.sort, seeded[parent] || [],
        "#{parent}'s subcategories drifted from production"
    end
  end

  # === Slugs referenced elsewhere in the app =============================
  #
  # Three separate places key off category slugs and all fail silently when a
  # slug is renamed: the related-category tiles just render fewer, the question
  # heading falls back, and `rake categories:seed_faqs` prints SKIP and moves on.

  test "every slug in RELATED_CATEGORIES is a real category" do
    referenced = CategoriesHelper::RELATED_CATEGORIES.keys +
                 CategoriesHelper::RELATED_CATEGORIES.values.flatten
    unknown = referenced.uniq - category_slugs

    assert_empty unknown, "RELATED_CATEGORIES references slugs no category has: #{unknown.join(', ')}"
  end

  test "every slug in CATEGORY_QUESTION_HEADINGS is a real category" do
    unknown = CategoriesHelper::CATEGORY_QUESTION_HEADINGS.keys - category_slugs

    assert_empty unknown, "CATEGORY_QUESTION_HEADINGS references slugs no category has: #{unknown.join(', ')}"
  end

  test "every key in category_faqs.yml is a real category" do
    keys = YAML.load_file(Rails.root.join("config", "category_faqs.yml")).keys
    unknown = keys - category_slugs - [ "branded-products" ]

    assert_empty unknown,
      "category_faqs.yml keys categories that do not exist, so categories:seed_faqs silently skips them: #{unknown.join(', ')}"
  end

  # === Route / redirect collisions =======================================

  test "no seeded slug is reserved by a permanent redirect" do
    collisions = category_slugs & Category::RESERVED_REDIRECT_SLUGS
    assert_empty collisions,
      "categories.csv seeds slugs rejected by Category's reserved-slug validation: #{collisions.join(', ')}"
  end

  test "no top-level slug is shadowed by a static category redirect" do
    shadowed = parent_rows.map { |r| r["slug"] } & ROUTE_REDIRECTED_SLUGS
    assert_empty shadowed,
      "these top-level slugs would be 301'd away by config/routes.rb before the app runs: #{shadowed.join(', ')}"
  end

  # === Products ==========================================================

  test "every product's category_slug exists in categories.csv" do
    missing = CSV.read(PRODUCTS_CSV, headers: true)
      .map { |r| r["category_slug"] }.compact.uniq - category_slugs

    assert_empty missing,
      "products.csv references categories that seeds never create: #{missing.join(', ')}"
  end

  test "products attach to leaf categories, never to parents" do
    parent_slugs = parent_rows.map { |r| r["slug"] }
    attached_to_parents = CSV.read(PRODUCTS_CSV, headers: true)
      .map { |r| r["category_slug"] }.compact.uniq & parent_slugs

    assert_empty attached_to_parents,
      "products.csv attaches products to top-level categories: #{attached_to_parents.join(', ')}"
  end
end
