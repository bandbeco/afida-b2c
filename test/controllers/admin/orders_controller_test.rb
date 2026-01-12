require "test_helper"

class Admin::OrdersControllerTest < ActionDispatch::IntegrationTest
  def setup
    @headers = { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }
    @admin = users(:acme_admin)
    sign_in_as(@admin)

    @regular_order = orders(:one)
    @sample_only_order = orders(:sample_only_order)
    @mixed_order = orders(:mixed_order)
  end

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }, headers: @headers
  end

  # Index tests

  test "index shows sample badges for sample-only orders" do
    get admin_orders_path, headers: @headers

    assert_response :success
    assert_select "span", text: /Samples Only/
  end

  test "index shows sample badges for mixed orders" do
    get admin_orders_path, headers: @headers

    assert_response :success
    assert_select "span", text: /Contains Samples/
  end

  test "index does not show sample badges for regular orders" do
    get admin_orders_path, headers: @headers

    assert_response :success
    # Find the row for regular order and ensure it doesn't have sample badges
    assert_select "tr" do |rows|
      regular_row = rows.find { |row| row.text.include?(@regular_order.display_number) }
      assert regular_row, "Should find row for regular order"
      refute regular_row.text.include?("Samples Only")
      refute regular_row.text.include?("Contains Samples")
    end
  end

  test "index filters by sample status - all" do
    get admin_orders_path(sample_status: "all"), headers: @headers

    assert_response :success
    assert_select "tr", minimum: 4 # At least headers + 3 orders
  end

  test "index filters by sample status - samples_only" do
    get admin_orders_path(sample_status: "samples_only"), headers: @headers

    assert_response :success
    assert_select "td", text: @sample_only_order.display_number
    assert_select "td", text: @regular_order.display_number, count: 0
  end

  test "index filters by sample status - contains_samples" do
    get admin_orders_path(sample_status: "contains_samples"), headers: @headers

    assert_response :success
    assert_select "td", text: @sample_only_order.display_number
    assert_select "td", text: @mixed_order.display_number
  end

  test "index filters by sample status - no_samples" do
    get admin_orders_path(sample_status: "no_samples"), headers: @headers

    assert_response :success
    assert_select "td", text: @regular_order.display_number
    assert_select "td", text: @sample_only_order.display_number, count: 0
    assert_select "td", text: @mixed_order.display_number, count: 0
  end

  test "index has sample status filter dropdown" do
    get admin_orders_path, headers: @headers

    assert_response :success
    assert_select "select[name='sample_status']"
    assert_select "option[value='all']"
    assert_select "option[value='samples_only']"
    assert_select "option[value='contains_samples']"
    assert_select "option[value='no_samples']"
  end

  # Show page tests

  test "show displays sample overlay on sample item images" do
    get admin_order_path(@sample_only_order), headers: @headers

    assert_response :success
    # Check for the SAMPLE overlay on images (same pattern as customer-facing cart)
    assert_select "span.bg-primary", text: /SAMPLE/
  end

  test "show displays effective sample SKU for sample items" do
    get admin_order_path(@sample_only_order), headers: @headers

    assert_response :success
    # effective_sample_sku is computed as SAMPLE-{sku}
    assert_select "p", text: /SAMPLE-SAMPLE-SW-8/
  end

  test "show distinguishes sample items from paid items in mixed orders" do
    get admin_order_path(@mixed_order), headers: @headers

    assert_response :success
    # Should show SAMPLE overlay only on sample items (1 sample, 1 paid)
    assert_select "span.bg-primary", text: /SAMPLE/, count: 1
  end
end
