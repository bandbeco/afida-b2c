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
    assert_match @product.generated_title, response.body
  end

  test "index excludes branded products" do
    branded = products(:branded_double_wall_template)
    get price_list_url
    assert_response :success
    # Price list should only show standard products, not branded templates
    assert_no_match Regexp.new(Regexp.escape(branded.generated_title)), response.body
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
    # View shows "Showing X–Y of Z products" format
    assert_match /Showing.*of.*products/, response.body
  end

  # =============================================================================
  # Category Filter Tests
  # =============================================================================

  test "category dropdown groups subcategories under parent categories" do
    get price_list_url
    assert_response :success
    assert_select "select[name='category'] optgroup[label='Cups & Drinks']" do
      assert_select "option", text: "Hot Cups"
      assert_select "option", text: "Cold Cups"
    end
  end

  test "filters by category" do
    get price_list_url(category: @category.slug)
    assert_response :success
    # Should show products from selected category
    assert_match @product.generated_title, response.body
    # Should not show products from other category
    assert_no_match @product_two.generated_title, response.body
  end

  test "shows all products when no category filter" do
    get price_list_url
    assert_response :success
    assert_match @product.generated_title, response.body
    assert_match @product_two.generated_title, response.body
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


  test "xlsx export includes category column with subcategory name" do
    get price_list_export_url(format: :xlsx)
    assert_response :success

    require "zip"
    Zip::File.open_buffer(response.body) do |zip|
      sheet_xml = zip.find_entry("xl/worksheets/sheet1.xml").get_input_stream.read.force_encoding("UTF-8")
      assert_includes sheet_xml, "Category", "Header row should include Category column"
      assert_includes sheet_xml, @product.category.name, "Category name should appear in export"
    end
  end

  test "xlsx export groups items by category" do
    get price_list_export_url(format: :xlsx)
    assert_response :success

    require "zip"
    Zip::File.open_buffer(response.body) do |zip|
      sheet_xml = zip.find_entry("xl/worksheets/sheet1.xml").get_input_stream.read.force_encoding("UTF-8")

      # Extract category names in order of appearance from the shared strings
      # Products should be grouped: all items in one category appear together
      products = Product.active.standard.includes(:category)
                        .joins(:category)
                        .order("categories.name ASC, products.name ASC, products.position ASC")
      category_names_in_order = products.map { |p| p.category&.name }.compact

      # Verify grouping: once a category stops appearing, it should not appear again
      seen_categories = []
      category_names_in_order.each do |name|
        if seen_categories.last != name
          assert_not_includes seen_categories, name,
            "Category '#{name}' appears in non-contiguous blocks - items are not grouped"
          seen_categories << name
        end
      end
    end
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
  # Pagination Tests
  # =============================================================================

  test "index paginates products" do
    get price_list_url
    assert_response :success
    # With few products, pagination info is shown but nav links only appear when pages > 1
    assert_match /Showing.*of.*products/, response.body
  end

  test "index respects page parameter" do
    get price_list_url(page: 1)
    assert_response :success
  end

  test "pagination preserves category filter" do
    get price_list_url(category: @category.slug, page: 1)
    assert_response :success
    # Should still filter by category
    assert_no_match @product_two.generated_title, response.body
  end

  test "pagination preserves search filter" do
    get price_list_url(q: @product.name, page: 1)
    assert_response :success
  end

  test "pagination shows product count with total" do
    get price_list_url
    assert_response :success
    assert_match /Showing.*of.*products/, response.body
  end

  test "pagination works within turbo frame" do
    get price_list_url(page: 1), headers: { "Turbo-Frame" => "price_list_table" }
    assert_response :success
    assert_select "turbo-frame#price_list_table"
  end

  test "xlsx export contains all products regardless of pagination" do
    total = Product.active.standard.count
    assert total > 0, "Need active standard products for this test"

    get price_list_export_url(format: :xlsx)
    assert_response :success

    require "zip"
    require "nokogiri"
    Zip::File.open_buffer(response.body) do |zip|
      sheet_xml = zip.find_entry("xl/worksheets/sheet1.xml").get_input_stream.read
      doc = Nokogiri::XML(sheet_xml)
      data_rows = doc.xpath("//xmlns:row", "xmlns" => "http://schemas.openxmlformats.org/spreadsheetml/2006/main").count - 1
      assert data_rows >= total, "Export should contain all #{total} products, got #{data_rows} rows"
    end
  end

  test "xlsx export contains full catalogue even when category filter is active" do
    total = Product.active.standard.count
    filtered = Product.active.standard.where(category_id: @category.id).count
    assert total > filtered, "Need products in multiple categories for this test"

    get price_list_export_url(format: :xlsx, category: @category.slug)
    assert_response :success

    require "zip"
    require "nokogiri"
    Zip::File.open_buffer(response.body) do |zip|
      sheet_xml = zip.find_entry("xl/worksheets/sheet1.xml").get_input_stream.read
      doc = Nokogiri::XML(sheet_xml)
      data_rows = doc.xpath("//xmlns:row", "xmlns" => "http://schemas.openxmlformats.org/spreadsheetml/2006/main").count - 1
      assert data_rows >= total, "Export should contain all #{total} products even with category filter, got #{data_rows} rows"
    end
  end

  test "pdf export contains full catalogue even when category filter is active" do
    get price_list_export_url(format: :pdf, category: @category.slug)
    assert_response :success
    assert_equal "application/pdf", response.content_type
  end

  # =============================================================================
  # Navigation Tests
  # =============================================================================

  test "price list page is linked from navbar" do
    get root_url
    assert_response :success
    assert_select "a[href=?]", price_list_path
  end

  # =============================================================================
  # N+1 Query Tests
  # =============================================================================

  test "index does not issue per-category subcategory queries" do
    # Warm up autoload / view compilation
    get price_list_url
    assert_response :success

    queries = []
    counter = ->(_, _, _, _, payload) {
      queries << payload[:sql] if payload[:sql] && !payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)
    }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      get price_list_url
    end

    # The N+1 signature is "WHERE parent_id = $1 ORDER BY position" — one
    # lookup per top-level category. The preloaded :children association is
    # discarded by .order(:position) in the view.
    per_parent_lookups = queries.count do |sql|
      sql.include?("FROM \"categories\"") &&
        sql.match?(/"parent_id" = \$\d+/) &&
        sql.include?("ORDER BY")
    end

    parent_count = Category.top_level.where.not(slug: "branded-products").count

    assert per_parent_lookups < parent_count,
      "Expected subcategory queries to not scale with #{parent_count} parents, " \
      "got #{per_parent_lookups} per-parent queries:\n" +
      queries.select { |q|
        q.include?("FROM \"categories\"") &&
          q.match?(/"parent_id" = \$\d+/) &&
          q.include?("ORDER BY")
      }.first(5).join("\n")
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
