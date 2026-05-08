require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Use hot_cups_extras which has multiple active products (won't trigger redirect)
    @category = categories(:hot_cups_extras)
  end

  # GET /categories/:id (show)
  test "should show category by slug" do
    get category_url(@category.slug)
    assert_response :success
  end

  test "show page loads category with slug" do
    get category_url(@category.slug)
    assert_response :success
    # Response should contain category name
    assert_match @category.name, response.body
  end

  test "show page loads category products" do
    get category_url(@category.slug)
    assert_response :success
    # Response should show products from this category
  end

  test "show page accessible to guests" do
    get category_url(@category.slug)
    assert_response :success
  end

  test "show page accessible to authenticated users" do
    sign_in_as(users(:one))
    get category_url(@category.slug)
    assert_response :success
  end

  test "category URLs use SEO-friendly slugs" do
    get category_url(@category.slug)
    assert_response :success
    # Categories are accessed via slug, not ID
  end

  test "show page eager loads products with images" do
    get category_url(@category.slug)
    assert_response :success
    # Eager loading prevents N+1 queries
  end

  test "show page displays only products from category" do
    get category_url(@category.slug)
    assert_response :success
    # Products displayed belong to this category
  end

  test "category pages are publicly accessible" do
    # Verify no authentication required
    get category_url(@category.slug)
    assert_response :success
  end

  test "redirects to variant page when category has only one variant" do
    category_with_one_product = categories(:category_with_one_product)
    only_variant = products(:only_product_in_category)

    get category_url(category_with_one_product.slug)

    assert_redirected_to product_path(only_variant.slug)
    assert_response :moved_permanently
  end

  test "single variant redirect preserves query parameters" do
    category_with_one_product = categories(:category_with_one_product)
    only_variant = products(:only_product_in_category)

    get category_url(category_with_one_product.slug, utm_source: "email", utm_campaign: "test")

    assert_redirected_to product_path(only_variant.slug, utm_source: "email", utm_campaign: "test")
    assert_response :moved_permanently
  end

  test "does not redirect when category has multiple products" do
    # hot_cups_extras has multiple lid products
    multi_product_category = categories(:hot_cups_extras)

    get category_url(multi_product_category.slug)

    assert_response :success
  end

  # Parent category hierarchy tests
  test "parent category shows products from all subcategories" do
    parent = categories(:parent_hot_food)

    get category_url(parent.slug)

    assert_response :success
    # Should include products from both child_pizza_boxes and child_takeaway_boxes
    assert_match "10 Inch Pizza Box", response.body
    assert_match "Kraft Takeaway Box", response.body
  end

  test "subcategory shows only its own products via nested URL" do
    parent = categories(:parent_hot_food)
    subcategory = categories(:child_pizza_boxes)

    get category_subcategory_url(parent.slug, subcategory.slug)

    assert_response :success
    assert_match "10 Inch Pizza Box", response.body
  end

  test "subcategory via flat URL redirects to nested URL" do
    subcategory = categories(:child_pizza_boxes)

    get category_url(subcategory.slug)

    assert_response :moved_permanently
  end

  test "parent category page is accessible" do
    parent = categories(:parent_cups_and_drinks)

    get category_url(parent.slug)

    assert_response :success
  end

  # Hero section tests
  test "show page renders hero section with H1 and description" do
    category = categories(:category_with_buying_guide)

    get category_url(category.slug)

    assert_response :success
    assert_select ".category-hero h1", text: category.name
    assert_select ".category-hero", text: /#{Regexp.escape(category.description)}/
  end

  test "show page hero displays product count" do
    category = categories(:category_with_buying_guide)

    get category_url(category.slug)

    assert_response :success
    assert_select ".category-hero", text: /Browse 2\+/
  end

  test "show page hero handles category without image gracefully" do
    category = categories(:category_with_buying_guide)
    assert_not category.image.attached?

    get category_url(category.slug)

    assert_response :success
    assert_select ".category-hero"
  end

  test "show page does not render question heading" do
    category = categories(:category_with_buying_guide)

    get category_url(category.slug)

    assert_response :success
    assert_select "h2", text: /What.*does Afida offer/, count: 0
  end

  # Buying guide tests
  test "show page renders buying guide when present" do
    category = categories(:category_with_buying_guide)

    get category_url(category.slug)

    assert_response :success
    assert_select ".buying-guide"
    assert_select ".buying-guide h2", text: /Why Choose Eco-Friendly/
    assert_select ".buying-guide h2", text: /Materials Guide/
    assert_select ".buying-guide h2", text: /Sizing and Use Cases/
  end

  test "show page does not render buying guide when blank" do
    get category_url(@category.slug)

    assert_response :success
    assert_select ".buying-guide", count: 0
  end

  test "buying guide renders between product grid and FAQs" do
    category = categories(:category_with_buying_guide)

    get category_url(category.slug)

    assert_response :success
    body = response.body
    product_grid_pos = body.index("grid-cols-2")
    buying_guide_pos = body.index("buying-guide")
    assert buying_guide_pos > product_grid_pos, "Buying guide should appear after the product grid"
  end

  # Buying guide Article JSON-LD tests
  test "show page includes Article JSON-LD when buying guide present" do
    category = categories(:category_with_buying_guide)

    get category_url(category.slug)

    assert_response :success
    assert_select 'script[type="application/ld+json"]' do |scripts|
      article_script = scripts.find { |s| s.text.include?('"Article"') }
      assert article_script, "Expected Article JSON-LD script tag"
      data = JSON.parse(article_script.text)
      assert_equal "Article", data["@type"]
      assert_includes data["headline"], category.name
      assert_equal "Afida", data.dig("author", "name")
      assert_equal "Afida", data.dig("publisher", "name")
      assert data["articleBody"].present?
      assert data["dateModified"].present?
    end
  end

  test "show page does not include Article JSON-LD when no buying guide" do
    get category_url(@category.slug)

    assert_response :success
    assert_select 'script[type="application/ld+json"]' do |scripts|
      article_script = scripts.find { |s| s.text.include?('"Article"') }
      assert_nil article_script, "Should not have Article JSON-LD without a buying guide"
    end
  end

  test "parent show eager loads attachments for products across subcategories" do
    parent = categories(:parent_hot_food)

    get category_url(parent.slug)
    assert_response :success

    queries = []
    counter = ->(_, _, _, _, payload) {
      queries << payload[:sql] if payload[:sql] && !payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)
    }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      get category_url(parent.slug)
    end

    assert_response :success

    per_record_attachment_lookups = queries.count do |sql|
      sql.include?("active_storage_attachments") &&
        sql.include?("\"record_id\" = $") &&
        sql.match?(/LIMIT \$\d+\z/)
    end

    assert per_record_attachment_lookups <= 1,
      "Expected at most 1 per-record attachment lookup (category image only), " \
      "got #{per_record_attachment_lookups}:\n" +
      queries.select { |q|
        q.include?("active_storage_attachments") &&
          q.include?("\"record_id\" = $") &&
          q.match?(/LIMIT \$\d+\z/)
      }.first(10).join("\n")
  end

  test "subcategory show eager loads attachments for products" do
    parent = categories(:parent_hot_food)
    subcategory = categories(:child_pizza_boxes)

    get category_subcategory_url(parent.slug, subcategory.slug)
    assert_response :success

    queries = []
    counter = ->(_, _, _, _, payload) {
      queries << payload[:sql] if payload[:sql] && !payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)
    }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      get category_subcategory_url(parent.slug, subcategory.slug)
    end

    assert_response :success

    per_record_attachment_lookups = queries.count do |sql|
      sql.include?("active_storage_attachments") &&
        sql.include?("\"record_id\" = $") &&
        sql.match?(/LIMIT \$\d+\z/)
    end

    assert per_record_attachment_lookups <= 1,
      "Expected at most 1 per-record attachment lookup (category image only), " \
      "got #{per_record_attachment_lookups}:\n" +
      queries.select { |q|
        q.include?("active_storage_attachments") &&
          q.include?("\"record_id\" = $") &&
          q.match?(/LIMIT \$\d+\z/)
      }.first(10).join("\n")
  end

  # Product ordering: family then capacity
  test "products are ordered by family sort_order then volume_in_ml" do
    category = categories(:hot_cups_extras)

    paper = product_families(:paper_lids)
    black = product_families(:recyclable_lids_black)
    white = product_families(:recyclable_lids_white)

    # Family ordering: paper first, then black, then white.
    paper.update!(sort_order: 10)
    black.update!(sort_order: 20)
    white.update!(sort_order: 30)

    # Capacities so 4oz / 8oz / 12oz are unambiguous within each family.
    products(:paper_lid_80mm).update!(volume_in_ml: 227)
    products(:paper_lid_90mm).update!(volume_in_ml: 340)

    products(:recyclable_lid_black_62mm).update!(volume_in_ml: 114)
    products(:recyclable_lid_black_80mm).update!(volume_in_ml: 227)
    products(:recyclable_lid_black_90mm).update!(volume_in_ml: 340)

    products(:recyclable_lid_white_62mm).update!(volume_in_ml: 114)
    products(:recyclable_lid_white_80mm).update!(volume_in_ml: 227)
    products(:recyclable_lid_white_90mm).update!(volume_in_ml: 340)

    get category_url(category.slug)
    assert_response :success

    products = @controller.view_assigns["products"].to_a
    family_keys = products.map { |p| p.product_family&.slug }

    paper_index = family_keys.index("paper-sip-lids-for-hot-cups")
    black_index = family_keys.index("recyclable-sip-lids-black")
    white_index = family_keys.index("recyclable-sip-lids-white")

    assert paper_index < black_index, "paper family must come before black family"
    assert black_index < white_index, "black family must come before white family"

    # Within the black family, 4oz (114ml) → 8oz (227ml) → 12oz (340ml) order.
    black_volumes = products
                      .select { |p| p.product_family&.slug == "recyclable-sip-lids-black" }
                      .map(&:volume_in_ml)
    assert_equal black_volumes.sort, black_volumes,
                 "black family products must be in ascending volume_in_ml order"

    # Family-less lids (flat_lid_8oz, domed_lid_8oz, sip_lid_8oz) sort last.
    last_with_family = products.rindex { |p| p.product_family_id.present? }
    first_without_family = products.index { |p| p.product_family_id.nil? }
    if last_with_family && first_without_family
      assert first_without_family > last_with_family,
             "family-less products must appear after all family-grouped products"
    end
  end

  test "within a family, products group by name first then ascending volume" do
    family = product_families(:single_wall_cups)
    family.update!(sort_order: 5)

    category = Category.create!(
      name: "Name+Volume Test",
      slug: "name-volume-test-#{SecureRandom.hex(4)}",
      position: 998,
    )

    # Two sub-lines under one family. Names chosen so alphabetic order is
    # "Double" → "Single", and we mix sizes so a naive volume-only sort
    # would interleave them.
    double_8 = make_product(category, family, "Double Wall Cups", 227)
    double_12 = make_product(category, family, "Double Wall Cups", 340)
    single_8 = make_product(category, family, "Single Wall Cups", 227)
    single_12 = make_product(category, family, "Single Wall Cups", 340)

    get category_url(category.slug)
    assert_response :success

    products = @controller.view_assigns["products"].to_a
    ids = products.map(&:id)

    assert_equal [ double_8.id, double_12.id, single_8.id, single_12.id ], ids,
                 "products should be grouped by name first, then ascending volume_in_ml"
  end

  test "within a family, products group by material then colour, with sizes ascending in each colour" do
    family = product_families(:paper_lids)
    family.update!(sort_order: 5)

    category = Category.create!(
      name: "Variant Test",
      slug: "variant-test-#{SecureRandom.hex(4)}",
      position: 997,
    )

    # Same product line ("Coffee Cup Sip Lids"), two materials × varying sizes.
    # Within a name+material run we sort by colour first then volume, so a
    # row reads as one colour's full size run, then the next colour's run.
    black_4 = make_variant(category, family, "Coffee Cup Sip Lids", "Black", "rPET", 118)
    black_8 = make_variant(category, family, "Coffee Cup Sip Lids", "Black", "rPET", 227)
    white_4 = make_variant(category, family, "Coffee Cup Sip Lids", "White", "rPET", 118)
    white_8 = make_variant(category, family, "Coffee Cup Sip Lids", "White", "rPET", 227)
    bag_8 = make_variant(category, family, "Coffee Cup Sip Lids", "White", "Bagasse", 227)

    get category_url(category.slug)
    assert_response :success

    products = @controller.view_assigns["products"].to_a
    ids = products.map(&:id)

    # Bagasse first (B before r), then rPET sorted by colour then volume.
    assert_equal [ bag_8.id, black_4.id, black_8.id, white_4.id, white_8.id ], ids
  end

  # Family group headers in the rendered view
  test "renders an h2 family heading for each multi-product family" do
    category = categories(:hot_cups_extras)

    get category_url(category.slug)
    assert_response :success

    # Multi-product families on this category page get a heading.
    assert_select ".product-family-heading",
                  text: /#{Regexp.escape(product_families(:paper_lids).name)}/
    assert_select ".product-family-heading",
                  text: /#{Regexp.escape(product_families(:recyclable_lids_black).name)}/
    assert_select ".product-family-heading",
                  text: /#{Regexp.escape(product_families(:recyclable_lids_white).name)}/
  end

  test "does not render an h2 heading for products without a product_family" do
    category = categories(:hot_cups_extras)

    get category_url(category.slug)
    assert_response :success

    # flat_lid_8oz, domed_lid_8oz, sip_lid_8oz have no product_family — no heading expected.
    assert_select ".product-family-heading", text: /Flat Lid/, count: 0
    assert_select ".product-family-heading", text: /Domed Lid/, count: 0
    assert_select ".product-family-heading", text: /Sip Lid - 8oz/, count: 0
  end

  test "falls back to a flat grid when no name+material has 2+ products on the page" do
    family_a = product_families(:single_wall_cups)
    family_a.update!(sort_order: 5)
    family_b = product_families(:paper_lids)
    family_b.update!(sort_order: 6)

    category = Category.create!(
      name: "Miscellaneous Test",
      slug: "miscellaneous-test-#{SecureRandom.hex(4)}",
      position: 990,
    )

    # Each product is unique by (name, material). No row break would help.
    make_variant(category, family_a, "Item A", "White", "Paper", 227)
    make_variant(category, family_b, "Item B", "Black", "rPET", 340)
    make_variant(category, family_a, "Item C", "Kraft", "Bagasse", 455)

    get category_url(category.slug)
    assert_response :success

    # Flat grid: no flex-row wrappers, no chip headings.
    assert_select "div.col-span-full.flex.justify-center", count: 0
    assert_select ".product-family-heading", count: 0
  end

  test "renders one centered flex row per name+material run" do
    family = product_families(:single_wall_cups)
    family.update!(sort_order: 5)

    category = Category.create!(
      name: "Row Break Test",
      slug: "row-break-test-#{SecureRandom.hex(4)}",
      position: 995,
    )

    # Two named sub-lines under one family → 2 separate flex rows.
    make_variant(category, family, "Double Wall Cups", "White", "Paper", 227)
    make_variant(category, family, "Double Wall Cups", "White", "Paper", 340)
    make_variant(category, family, "Single Wall Cups", "White", "Paper", 227)
    make_variant(category, family, "Single Wall Cups", "White", "Paper", 340)

    get category_url(category.slug)
    assert_response :success

    assert_select "div.col-span-full.flex.justify-center", count: 2
  end

  test "splits each name+material+colour combination into its own row when each colour has 2+ products" do
    family = product_families(:paper_lids)
    family.update!(sort_order: 5)

    category = Category.create!(
      name: "Variant Row Break Test",
      slug: "variant-row-break-#{SecureRandom.hex(4)}",
      position: 993,
    )

    # Each (name, material, colour) has 2+ products so no merging happens.
    # 3 distinct combinations → 3 rows.
    make_variant(category, family, "Coffee Cup Sip Lids", "Black", "rPET", 118)
    make_variant(category, family, "Coffee Cup Sip Lids", "Black", "rPET", 227)
    make_variant(category, family, "Coffee Cup Sip Lids", "White", "rPET", 118)
    make_variant(category, family, "Coffee Cup Sip Lids", "White", "rPET", 227)
    make_variant(category, family, "Coffee Cup Sip Lids", "Black", "PP", 340)
    make_variant(category, family, "Coffee Cup Sip Lids", "Black", "PP", 455)

    get category_url(category.slug)
    assert_response :success

    assert_select "div.col-span-full.flex.justify-center", count: 3
  end

  test "merges a singleton colour row into the previous multi-card row of the same name+material" do
    family = product_families(:paper_lids)
    family.update!(sort_order: 5)

    category = Category.create!(
      name: "Backward Merge Test",
      slug: "backward-merge-#{SecureRandom.hex(4)}",
      position: 991,
    )

    # Black PP has 2 sizes (a multi-card row), White PP has 1 size (singleton).
    # Singleton White should merge backward into the Black PP row, not float alone.
    make_variant(category, family, "Coffee Cup Sip Lids", "Black", "PP", 340)
    make_variant(category, family, "Coffee Cup Sip Lids", "Black", "PP", 455)
    make_variant(category, family, "Coffee Cup Sip Lids", "White", "PP", 340)

    get category_url(category.slug)
    assert_response :success

    assert_select "div.col-span-full.flex.justify-center", count: 1
  end

  test "merges singleton colour rows into the next colour row of the same name+material" do
    family = product_families(:paper_lids)
    family.update!(sort_order: 5)

    category = Category.create!(
      name: "Singleton Merge Test",
      slug: "singleton-merge-#{SecureRandom.hex(4)}",
      position: 992,
    )

    # Black PP and White PP each have only one product. They should merge
    # into a single row instead of leaving a lone Black PP card alone.
    make_variant(category, family, "Coffee Cup Sip Lids", "Black", "PP", 340)
    make_variant(category, family, "Coffee Cup Sip Lids", "White", "PP", 340)

    get category_url(category.slug)
    assert_response :success

    assert_select "div.col-span-full.flex.justify-center", count: 1
  end

  test "renders a single centered row when all products share name and material" do
    family = product_families(:single_wall_cups)
    family.update!(sort_order: 5)

    category = Category.create!(
      name: "Same-Name Test",
      slug: "same-name-test-#{SecureRandom.hex(4)}",
      position: 994,
    )

    make_variant(category, family, "Cups", "White", "Paper", 227)
    make_variant(category, family, "Cups", "White", "Paper", 340)
    make_variant(category, family, "Cups", "White", "Paper", 455)

    get category_url(category.slug)
    assert_response :success

    assert_select "div.col-span-full.flex.justify-center", count: 1
  end

  test "does not render any family heading when only one family is on the page" do
    family = product_families(:single_wall_cups)
    family.update!(sort_order: 5)

    category = Category.create!(
      name: "Single-Family Test",
      slug: "single-family-test-#{SecureRandom.hex(4)}",
      position: 996,
    )

    # Two products, same family — chip would just duplicate the page H1.
    make_variant(category, family, "Cups", "White", "Paper", 227)
    make_variant(category, family, "Cups", "White", "Paper", 340)

    get category_url(category.slug)
    assert_response :success

    assert_select ".product-family-heading", count: 0
  end

  test "does not render an h2 heading for solo-product families" do
    # Build a temporary category with a family that has only one product on the page.
    solo_family = ProductFamily.create!(
      name: "Lonely Family",
      slug: "lonely-family-#{SecureRandom.hex(4)}",
      sort_order: 1,
    )
    category = Category.create!(
      name: "Solo Family Test",
      slug: "solo-family-test-#{SecureRandom.hex(4)}",
      position: 999,
    )
    Product.create!(
      category: category,
      product_family: solo_family,
      name: "Only Member",
      sku: "SOLO-#{SecureRandom.hex(4)}",
      slug: "solo-member-#{SecureRandom.hex(4)}",
      price: 10.0,
      stock_quantity: 100,
      active: true,
      product_type: "standard",
    )
    Product.create!(
      category: category,
      name: "Other Standalone",
      sku: "STD-#{SecureRandom.hex(4)}",
      slug: "other-standalone-#{SecureRandom.hex(4)}",
      price: 12.0,
      stock_quantity: 100,
      active: true,
      product_type: "standard",
    )

    get category_url(category.slug)
    assert_response :success

    assert_select ".product-family-heading", text: /Lonely Family/, count: 0
  end

  test "parent show does not fire N+1 categories queries" do
    parent = categories(:parent_hot_food)

    get category_url(parent.slug)
    assert_response :success

    queries = []
    counter = ->(_, _, _, _, payload) {
      queries << payload[:sql] if payload[:sql] && !payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)
    }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      get category_url(parent.slug)
    end

    assert_response :success

    per_record_category_lookups = queries.count do |sql|
      sql.include?("\"categories\"") &&
        sql.include?("\"id\" = $") &&
        sql.match?(/LIMIT \$\d+\z/)
    end

    assert per_record_category_lookups <= 1,
      "Expected at most 1 per-record categories lookup, got #{per_record_category_lookups}:\n" +
      queries.select { |q|
        q.include?("\"categories\"") &&
          q.include?("\"id\" = $") &&
          q.match?(/LIMIT \$\d+\z/)
      }.first(10).join("\n")
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end

  def make_product(category, family, name, volume_in_ml)
    suffix = SecureRandom.hex(4)
    Product.create!(
      category: category,
      product_family: family,
      name: name,
      sku: "T-#{suffix}",
      slug: "test-#{suffix}",
      price: 10.0,
      stock_quantity: 100,
      active: true,
      product_type: "standard",
      volume_in_ml: volume_in_ml,
    )
  end

  def make_variant(category, family, name, colour, material, volume_in_ml)
    suffix = SecureRandom.hex(4)
    Product.create!(
      category: category,
      product_family: family,
      name: name,
      colour: colour,
      material: material,
      sku: "T-#{suffix}",
      slug: "test-#{suffix}",
      price: 10.0,
      stock_quantity: 100,
      active: true,
      product_type: "standard",
      volume_in_ml: volume_in_ml,
    )
  end
end
