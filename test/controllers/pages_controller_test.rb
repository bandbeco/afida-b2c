require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "shop page displays all products by default" do
    get shop_path

    assert_response :success
    assert_select "h1", text: /Shop/
    # Verify at least one product link is present
    product = Product.active.catalog_products.first
    assert_select "a[href=?]", product_path(product.slug)
  end

  test "shop page filters by categories" do
    category = categories(:one)
    product = products(:one)
    product.update(category: category)

    get shop_path, params: { categories: [ category.slug ] }

    assert_response :success
    assert_select "a[href=?]", product_path(product.slug)
  end

  test "shop page searches products" do
    product = products(:one)
    product.update(name: "Pizza Box")

    get shop_path, params: { q: "pizza" }

    assert_response :success
    assert_select "a[href=?]", product_path(product.slug)
  end

  test "shop page sorts products by price" do
    get shop_path, params: { sort: "price_asc" }

    assert_response :success
    # Verify products are present (specific order checking in system tests)
  end

  test "shop page handles excessive page number gracefully" do
    get shop_path, params: { page: 999999 }

    assert_response :success
    # Pagy overflow handling should redirect to last page, not crash
  end

  test "shop page handles invalid sort parameter safely" do
    get shop_path, params: { sort: "invalid_sort" }

    assert_response :success
    # Should fall back to default sort, not crash
  end

  test "shop page handles excessively long search query safely" do
    long_query = "a" * 200

    get shop_path, params: { q: long_query }

    assert_response :success
    # Query should be truncated to 100 chars, not cause errors
  end

  test "shop page handles nested brand param safely" do
    get shop_path, params: { brand: { foo: "bar" } }

    assert_response :success
  end

  test "shop page handles nested colour param safely" do
    get shop_path, params: { colour: { foo: "bar" } }

    assert_response :success
  end

  test "shop page handles nested material param safely" do
    get shop_path, params: { material: { foo: "bar" } }

    assert_response :success
  end

  test "shop page filters by size" do
    # Use fixture variant with size option
    variant = products(:single_wall_8oz_white)

    get shop_path, params: { size: "8oz" }

    assert_response :success
    assert_select "a[href=?]", product_path(variant.slug)
  end

  test "shop page filters by colour" do
    # Set colour on fixture product for filtering
    product = products(:single_wall_8oz_white)
    product.update!(colour: "White")

    get shop_path, params: { colour: "White" }

    assert_response :success
    assert_select "a[href=?]", product_path(product.slug)
  end

  test "shop page filters by material" do
    # Set material on fixture product for filtering
    product = products(:wooden_fork)
    product.update!(material: "Birch")

    get shop_path, params: { material: "Birch" }

    assert_response :success
    assert_select "a[href=?]", product_path(product.slug)
  end

  test "shop page combines multiple filters" do
    # Set colour and material on fixture products for filtering
    white_product = products(:single_wall_8oz_white)
    white_product.update!(colour: "White", material: "Paper")

    black_product = products(:single_wall_8oz_black)
    black_product.update!(colour: "Black", material: "Paper")

    get shop_path, params: { colour: "White", material: "Paper" }

    assert_response :success
    assert_select "a[href=?]", product_path(white_product.slug)

    # Should NOT include product with different colour
    assert_select "a[href=?]", product_path(black_product.slug), count: 0
  end

  test "shop page returns success with available_filters" do
    get shop_path

    assert_response :success
    # Available filters are used in the view - test indirectly through response
  end

  test "shop page filters can combine with category filter" do
    product = products(:single_wall_8oz_white)
    product.update!(colour: "White")
    category = product.category

    get shop_path, params: { categories: [ category.slug ], colour: "White" }

    assert_response :success
    assert_select "a[href=?]", product_path(product.slug)
  end

  test "shop page filters can combine with search" do
    product = products(:single_wall_8oz_white)
    product.update!(colour: "White")

    # Search by SKU which is guaranteed to match
    get shop_path, params: { q: product.sku, colour: "White" }

    assert_response :success
    assert_select "a[href=?]", product_path(product.slug)
  end

  test "shop page handles empty filter results gracefully" do
    get shop_path, params: { colour: "nonexistent_colour_12345" }

    assert_response :success
    # Should show empty state or "no results" message
  end

  # =========================================================================
  # Legacy category filter slug redirects (SEO)
  # Old /shop?categories[]=<legacy-slug> URLs from external backlinks
  # should 301 to the matching new category page.
  # =========================================================================

  test "shop page 301 redirects legacy cups-and-lids filter to new category" do
    get shop_path, params: { categories: [ "cups-and-lids" ] }

    assert_response :moved_permanently
    assert_redirected_to "/categories/cups-and-drinks"
  end

  test "shop page 301 redirects legacy ice-cream-cups filter to new subcategory" do
    get shop_path, params: { categories: [ "ice-cream-cups" ] }

    assert_response :moved_permanently
    assert_redirected_to "/categories/cups-and-drinks/ice-cream-cups"
  end

  test "shop page 301 redirects legacy napkins filter to new subcategory" do
    get shop_path, params: { categories: [ "napkins" ] }

    assert_response :moved_permanently
    assert_redirected_to "/categories/tableware/napkins"
  end

  test "shop page 301 redirects legacy pizza-boxes filter to new subcategory" do
    get shop_path, params: { categories: [ "pizza-boxes" ] }

    assert_response :moved_permanently
    assert_redirected_to "/categories/hot-food/pizza-boxes"
  end

  test "shop page does not redirect when legacy slug matches an existing category" do
    # If a current category slug happens to collide with a legacy-list entry,
    # we should prefer the standard filter behaviour rather than redirect.
    existing = categories(:one)

    get shop_path, params: { categories: [ existing.slug ] }

    assert_response :success
  end

  test "shop page does not redirect when multiple filter slugs are selected" do
    # Multi-select is an active filter action by the user, not a stale backlink.
    get shop_path, params: { categories: [ "cups-and-lids", "napkins" ] }

    assert_response :success
  end

  # =========================================================================
  # Vegware landing page tests
  # =========================================================================

  test "vegware page returns 200" do
    get vegware_path

    assert_response :success
  end

  test "vegware page displays Vegware in H1" do
    get vegware_path

    assert_select "h1", /Vegware/i
  end

  test "vegware page shows Vegware product categories" do
    get vegware_path

    collection = collections(:vegware)
    category = categories(:parent_cups_and_drinks)
    assert_select "a[href=?]", category_filter_collection_path(collection, category_slug: category.slug)
  end

  test "vegware page has correct meta title" do
    get vegware_path

    assert_select "title", /Vegware/
  end

  test "vegware page has canonical URL" do
    get vegware_path

    assert_select "link[rel=canonical][href=?]", vegware_url
  end

  test "vegware page has structured data" do
    get vegware_path

    assert_select "script[type='application/ld+json']"
  end

  test "vegware page has FAQ section with collapse elements" do
    get vegware_path

    assert_select ".collapse", minimum: 5
  end

  test "vegware page has CTA buttons" do
    get vegware_path

    assert_select "a[href='#vegware-products']"
    assert_select "a[href=?]", samples_path
  end

  test "vegware page shows first product photo for each category card" do
    product = products(:vegware_hot_cup)
    product.product_photo.attach(
      io: StringIO.new("fake image data"),
      filename: "test.jpg",
      content_type: "image/jpeg"
    )

    get vegware_path

    assert_response :success
    assert_select ".aspect-square img", minimum: 1
  end

  test "shop page eager loads product attachments to avoid N+1" do
    # Warm up the response cycle (autoload / view compilation)
    get shop_path
    assert_response :success

    queries = []
    counter = ->(_, _, _, _, payload) {
      queries << payload[:sql] if payload[:sql] && !payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)
    }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      get shop_path
    end

    # Per-product attachment lookups are the N+1 signature: a separate
    # "record_id = $1 ... LIMIT 1" query for each product's photo. Eager-loaded
    # preloads use "record_id IN (...)" instead.
    per_record_lookups = queries.count do |sql|
      sql.include?("active_storage_attachments") &&
        sql.include?("\"record_id\" = $") &&
        sql.match?(/LIMIT \$\d+\z/)
    end

    product_count = Product.active.standard.count

    # The page renders one product card per active standard product. Without
    # eager loading, each card's `lifestyle_photo.attached?` triggers a query.
    # With eager loading, the count is bounded (and unrelated to product_count).
    assert per_record_lookups < product_count,
      "Expected attachment lookups to not scale with #{product_count} products, " \
      "got #{per_record_lookups} per-record queries:\n" +
      queries.select { |q|
        q.include?("active_storage_attachments") &&
          q.include?("\"record_id\" = $") &&
          q.match?(/LIMIT \$\d+\z/)
      }.first(5).join("\n")
  end
end
