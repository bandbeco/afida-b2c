require "test_helper"

class VegwareCollectionTest < ActionDispatch::IntegrationTest
  setup do
    @vegware = collections(:vegware)
    @vegware_hot_cup = products(:vegware_hot_cup)
    @vegware_straw = products(:vegware_straw)
    @vegware_napkin = products(:vegware_napkin)
    @vegware_inactive = products(:vegware_inactive)
    @parent_cups_and_drinks = categories(:parent_cups_and_drinks)
  end

  # ==========================================================================
  # GET /collections/vegware (all Vegware products)
  # ==========================================================================

  test "vegware collection page shows all active Vegware products" do
    get collection_url(@vegware.slug)
    assert_response :success
    assert_match @vegware_hot_cup.name, response.body
    assert_match @vegware_straw.name, response.body
    assert_match @vegware_napkin.name, response.body
  end

  test "vegware collection page excludes inactive products" do
    get collection_url(@vegware.slug)
    assert_response :success
    assert_no_match(/Vegware Inactive Cup/, response.body)
  end

  # ==========================================================================
  # GET /collections/vegware/:category_slug (filtered by parent category)
  # ==========================================================================

  test "vegware category filter page shows only products in that parent category" do
    get category_filter_collection_url(@vegware.slug, @parent_cups_and_drinks.slug)
    assert_response :success
    # Hot cup is in Cups & Drinks (via child_hot_cups subcategory)
    assert_match @vegware_hot_cup.name, response.body
    # Straw is also in Cups & Drinks (straws category — but in fixtures it's a flat category, not a child)
  end

  test "vegware category filter page excludes products from other categories" do
    get category_filter_collection_url(@vegware.slug, @parent_cups_and_drinks.slug)
    assert_response :success
    # Napkin is in hot-food (pizza-boxes), not in cups-and-drinks
    assert_no_match(/Vegware Napkin/, response.body)
  end

  test "vegware category filter page excludes inactive products" do
    get category_filter_collection_url(@vegware.slug, @parent_cups_and_drinks.slug)
    assert_response :success
    assert_no_match(/Vegware Inactive Cup/, response.body)
  end

  test "vegware category filter returns 404 for non-existent category slug" do
    get "/collections/vegware/non-existent-category"
    assert_response :not_found
  end

  test "vegware category filter returns 404 for non-vegware collection" do
    get "/collections/coffee-shop-essentials/cups-and-drinks"
    assert_response :not_found
  end

  # ==========================================================================
  # SEO — meta tags on filtered page
  # ==========================================================================

  test "vegware category filter page has unique H1" do
    get category_filter_collection_url(@vegware.slug, @parent_cups_and_drinks.slug)
    assert_response :success
    assert_select "h1", text: /Vegware.*Cups & Drinks/
  end

  test "vegware category filter page has unique meta title" do
    get category_filter_collection_url(@vegware.slug, @parent_cups_and_drinks.slug)
    assert_response :success
    assert_select "title", text: /Vegware.*Cups & Drinks/
  end

  test "vegware category filter page has meta description" do
    get category_filter_collection_url(@vegware.slug, @parent_cups_and_drinks.slug)
    assert_response :success
    assert_select "meta[name=description]" do |elements|
      assert elements.any? { |e| e[:content].include?("Vegware") && e[:content].include?("Cups & Drinks") }
    end
  end

  test "vegware category filter page has canonical URL" do
    get category_filter_collection_url(@vegware.slug, @parent_cups_and_drinks.slug)
    assert_response :success
    assert_select "link[rel=canonical]"
  end

  test "vegware category filter page has structured data" do
    get category_filter_collection_url(@vegware.slug, @parent_cups_and_drinks.slug)
    assert_response :success
    assert_select "script[type='application/ld+json']"
  end

  test "vegware category filter page has breadcrumbs" do
    get category_filter_collection_url(@vegware.slug, @parent_cups_and_drinks.slug)
    assert_response :success
    assert_match "Home", response.body
    assert_match "Vegware", response.body
    assert_match "Cups &amp; Drinks", response.body
  end

  # ==========================================================================
  # Route / URL helpers
  # ==========================================================================

  test "vegware category filter URL uses collection slug and category slug" do
    url = category_filter_collection_url(@vegware.slug, @parent_cups_and_drinks.slug)
    assert_includes url, "/collections/vegware/cups-and-drinks"
  end

  # ==========================================================================
  # Navigation — Vegware in mega-menu
  # ==========================================================================

  test "desktop mega-menu includes Vegware entry" do
    get root_url
    assert_response :success
    assert_select "[data-controller='category-mega-menu']" do
      assert_select "button", text: /Vegware/
    end
  end

  test "desktop mega-menu Vegware panel shows category filter links" do
    get root_url
    assert_response :success
    assert_select "#category-panel-vegware" do
      assert_select "a[href*='/collections/vegware/']", minimum: 1
    end
  end

  test "mobile menu includes Vegware drill-down entry" do
    get root_url
    assert_response :success
    assert_select "[data-controller='mobile-menu']" do
      assert_select "button", text: /Vegware/
    end
  end

  test "mobile menu Vegware subcategory panel shows category filter links" do
    get root_url
    assert_response :success
    assert_select "[data-category='vegware']" do
      assert_select "a[href*='/collections/vegware/']", minimum: 1
    end
  end
end
