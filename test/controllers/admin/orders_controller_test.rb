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

  # The admin order summary renders via OrderSummary (shared with the storefront
  # pages, emails and PDF), so a discounted order shows the Discount line and a
  # plain order omits it. Previously the admin page had no discount line at all.
  test "show renders the discount line for a discounted order" do
    @regular_order.update!(discount_amount: 2.50, discount_code: "WELCOME10")
    get admin_order_path(@regular_order), headers: @headers

    assert_response :success
    assert_select "span", text: "Discount (WELCOME10)"
    assert_select "span", text: "-£2.50"
  end

  test "show omits the discount line for an order without a discount" do
    get admin_order_path(@regular_order), headers: @headers # default zero discount

    assert_response :success
    assert_select "span", text: /Discount/, count: 0
  end

  # The address block renders via OrderAddress (shared with the storefront
  # pages, ops email and PDF): billing appears only when collected, and as a
  # "Same as delivery address" note when it matches the delivery address.
  test "show renders the shipping address and no billing block by default" do
    get admin_order_path(@regular_order), headers: @headers

    assert_response :success
    assert_match @regular_order.shipping_address_line1, response.body
    assert_no_match(/Billing Address/, response.body)
  end

  test "show renders a distinct billing address when one was collected" do
    @regular_order.update_columns(
      billing_name: "Accounts Payable", billing_address_line1: "1 Finance Row",
      billing_city: "Manchester", billing_postal_code: "M1 1AA", billing_country: "GB"
    )
    get admin_order_path(@regular_order), headers: @headers

    assert_match "Billing Address", response.body
    assert_match "1 Finance Row", response.body
  end

  test "show renders a same-as-delivery note when billing matches shipping" do
    @regular_order.update_columns(
      billing_name: @regular_order.shipping_name,
      billing_address_line1: @regular_order.shipping_address_line1,
      billing_address_line2: @regular_order.shipping_address_line2,
      billing_city: @regular_order.shipping_city,
      billing_postal_code: @regular_order.shipping_postal_code,
      billing_country: @regular_order.shipping_country
    )
    get admin_order_path(@regular_order), headers: @headers

    assert_match "Same as delivery address", response.body
    assert_equal 1, response.body.scan(@regular_order.shipping_address_line1).count
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
    # Note: count is 2 because there's both desktop and mobile layouts for the sample item
    assert_select "span.bg-primary", text: /SAMPLE/, count: 2
  end
end
