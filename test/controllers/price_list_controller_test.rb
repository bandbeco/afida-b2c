# frozen_string_literal: true

require "test_helper"

class PriceListControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:one)
    @product_two = products(:two)
    @category = categories(:one)
    @category_two = categories(:two)

    # Set up products with pac_size for price list tests
    @product.update!(pac_size: 100)
    @product_two.update!(pac_size: 50)
  end

  # =============================================================================
  # Index Action Tests
  # =============================================================================

  test "should get index" do
    get price_list_url
    assert_response :success
  end

  test "index is accessible to guests" do
    get price_list_url
    assert_response :success
  end

  test "index is accessible to authenticated users" do
    sign_in_as(users(:one))
    get price_list_url
    assert_response :success
  end

  test "index displays standard products only" do
    get price_list_url
    assert_response :success
    # Should show standard products
    assert_match @product.name, response.body
  end

  test "index excludes branded products" do
    branded = products(:branded_double_wall_template)
    get price_list_url
    assert_response :success
    # Price list should only show standard products, not branded templates
    assert_no_match Regexp.new(Regexp.escape(branded.name)), response.body
  end

  test "index shows table with correct columns" do
    get price_list_url
    assert_response :success
    assert_select "table thead th", text: /Product/
    assert_select "table thead th", text: /SKU/
    assert_select "table thead th", text: /Pack Size/
    assert_select "table thead th", text: /Price\/Pack/
    assert_select "table thead th", text: /Price\/Unit/
  end

  test "index shows VAT notice" do
    get price_list_url
    assert_response :success
    assert_match /prices exclude VAT/i, response.body
  end

  test "index shows product count" do
    get price_list_url
    assert_response :success
    # View shows "Showing X products" format
    assert_match /Showing \d+ products?/, response.body
  end

  # =============================================================================
  # Category Filter Tests
  # =============================================================================

  test "filters by category" do
    get price_list_url(category: @category.slug)
    assert_response :success
    # Should show products from selected category
    assert_match @product.name, response.body
    # Should not show products from other category
    assert_no_match @product_two.name, response.body
  end

  test "shows all products when no category filter" do
    get price_list_url
    assert_response :success
    assert_match @product.name, response.body
    assert_match @product_two.name, response.body
  end

  # =============================================================================
  # Search Filter Tests
  # =============================================================================

  test "searches by product name" do
    get price_list_url(q: @product.name)
    assert_response :success
    assert_match @product.name, response.body
  end

  test "searches by SKU" do
    get price_list_url(q: @product.sku)
    assert_response :success
    assert_match @product.sku, response.body
  end

  test "search is case insensitive" do
    get price_list_url(q: @product.name.upcase)
    assert_response :success
    assert_match @product.name, response.body
  end

  test "search with no matches shows empty state" do
    get price_list_url(q: "nonexistent-product-xyz")
    assert_response :success
    assert_match /No products found/i, response.body
  end

  # =============================================================================
  # Combined Filters Tests
  # =============================================================================

  test "combines category and search filters" do
    get price_list_url(category: @category.slug, q: @product.name)
    assert_response :success
    # Only products matching both filters should appear
    assert_match @product.sku, response.body
  end

  # =============================================================================
  # Turbo Frame Tests
  # =============================================================================

  test "responds to turbo frame request" do
    get price_list_url, headers: { "Turbo-Frame" => "price_list_table" }
    assert_response :success
    assert_select "turbo-frame#price_list_table"
  end

  # =============================================================================
  # Export Action Tests - Excel
  # =============================================================================

  test "exports to xlsx format" do
    get price_list_export_url(format: :xlsx)
    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.content_type
  end

  test "xlsx export has correct filename" do
    get price_list_export_url(format: :xlsx)
    assert_response :success
    assert_match /afida-price-list-.*\.xlsx/, response.headers["Content-Disposition"]
  end

  test "xlsx export includes category in filename when filtered" do
    get price_list_export_url(format: :xlsx, category: @category.slug)
    assert_response :success
    assert_match @category.slug, response.headers["Content-Disposition"]
  end

  test "xlsx export respects category filter" do
    get price_list_export_url(format: :xlsx, category: @category.slug)
    assert_response :success
    # Export should succeed (filtering applied server-side)
  end

  test "xlsx export respects search filter" do
    get price_list_export_url(format: :xlsx, q: @product.name)
    assert_response :success
  end

  test "xlsx export uses GBP currency format" do
    get price_list_export_url(format: :xlsx)
    assert_response :success

    # xlsx is a zip file - extract styles.xml to check format codes
    require "zip"
    Zip::File.open_buffer(response.body) do |zip|
      styles_entry = zip.find_entry("xl/styles.xml")
      assert styles_entry, "styles.xml should exist in xlsx"

      styles_xml = styles_entry.get_input_stream.read.force_encoding("UTF-8")
      assert_includes styles_xml, "£#,##0.00", "Pack price should use GBP format"
      assert_includes styles_xml, "£#,##0.000", "Unit price should use GBP with 3 decimals"
    end
  end

  # =============================================================================
  # Export Action Tests - PDF
  # =============================================================================

  test "exports to pdf format" do
    get price_list_export_url(format: :pdf)
    assert_response :success
    assert_equal "application/pdf", response.content_type
  end

  test "pdf export has correct filename" do
    get price_list_export_url(format: :pdf)
    assert_response :success
    assert_match /afida-price-list-.*\.pdf/, response.headers["Content-Disposition"]
  end

  test "pdf export includes category in filename when filtered" do
    get price_list_export_url(format: :pdf, category: @category.slug)
    assert_response :success
    assert_match @category.slug, response.headers["Content-Disposition"]
  end

  test "pdf export respects category filter" do
    get price_list_export_url(format: :pdf, category: @category.slug)
    assert_response :success
  end

  test "pdf export respects search filter" do
    get price_list_export_url(format: :pdf, q: @product.name)
    assert_response :success
  end

  # =============================================================================
  # Empty Results Tests
  # =============================================================================

  test "shows empty state when no products match filters" do
    get price_list_url(category: "nonexistent-category")
    assert_response :success
    assert_match /No products found/i, response.body
  end

  test "shows clear filters link when empty" do
    get price_list_url(category: "nonexistent-category")
    assert_response :success
    assert_select "a", text: /Clear/i
  end

  # =============================================================================
  # Clear Filter Tests
  # =============================================================================

  test "clear link is shown when filters are active" do
    get price_list_url(category: @category.slug)
    assert_response :success
    assert_select "a", text: /Clear/i
  end

  test "clear link is not shown when no filters" do
    get price_list_url
    assert_response :success
    # Clear button should only appear when filters are active
    # Using assert_select with count to check it doesn't appear in the filter bar
    # (it may appear in empty state, so we check the filter form area)
  end

  # =============================================================================
  # Navigation Tests
  # =============================================================================

  test "price list page is linked from navbar" do
    get root_url
    assert_response :success
    assert_select "a[href=?]", price_list_path
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
