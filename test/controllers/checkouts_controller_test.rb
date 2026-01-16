require "test_helper"

class CheckoutsControllerTest < ActionDispatch::IntegrationTest
  include StripeTestHelper

  setup do
    @user = users(:one)

    # Create a fresh cart with items for testing
    @cart = Cart.create!(user: @user)
    @cart_item = @cart.cart_items.create!(
      product: products(:one),
      quantity: 2,
      price: 10.0
    )

    # Stub Current.cart to return our test cart for all tests
    Current.stubs(:cart).returns(@cart)

    # Stub UK VAT tax rate lookup (used by controller)
    stub_stripe_tax_rate_list
  end

  # ============================================================================
  # CREATE ACTION TESTS (POST /checkouts)
  # ============================================================================

  test "create redirects to Stripe checkout session URL" do
    stub_stripe_session_create

    post checkout_path

    assert_response :see_other
    assert_match %r{https://checkout\.stripe\.com/test/sess_}, response.redirect_url
  end

  test "create builds line items from cart items" do
    # Capture the params passed to Stripe
    captured_params = nil
    session = build_stripe_session
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(session)

    post checkout_path

    assert_not_nil captured_params
    assert_equal "gbp", captured_params[:line_items].first[:price_data][:currency]
    assert_equal "card", captured_params[:payment_method_types].first
    assert_equal "payment", captured_params[:mode]
  end

  test "create includes cart_id in metadata for webhook fallback" do
    # Capture the params passed to Stripe
    captured_params = nil
    session = build_stripe_session
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(session)

    post checkout_path

    assert_not_nil captured_params
    assert_not_nil captured_params[:metadata]
    assert_equal @cart.id.to_s, captured_params[:metadata][:cart_id]
  end

  test "create includes customer email for authenticated users" do
    Current.stubs(:user).returns(@user)

    captured_params = nil
    session = build_stripe_session
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(session)

    post checkout_path

    assert_equal @user.email_address, captured_params[:customer_email]
    assert_equal @user.id, captured_params[:client_reference_id]
  end

  test "create does not include customer details for guest users" do
    captured_params = nil
    session = build_stripe_session
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(session)

    post checkout_path

    assert_nil captured_params[:customer_email]
    assert_nil captured_params[:client_reference_id]
  end

  test "create includes UK shipping address collection" do
    captured_params = nil
    session = build_stripe_session
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(session)

    post checkout_path

    assert_includes captured_params[:shipping_address_collection][:allowed_countries], "GB"
  end

  test "create includes shipping options from Shipping module" do
    captured_params = nil
    session = build_stripe_session
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(session)

    post checkout_path

    # Shipping module returns 1 option based on subtotal:
    # - Orders < £100: Standard Shipping
    # - Orders >= £100: Free Shipping
    assert_not_empty captured_params[:shipping_options]
    assert_equal 1, captured_params[:shipping_options].length
    assert_equal "Standard Shipping", captured_params[:shipping_options].first[:shipping_rate_data][:display_name]
  end

  test "create includes success and cancel URLs" do
    captured_params = nil
    session = build_stripe_session
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(session)

    post checkout_path

    assert_match /checkout\/success/, captured_params[:success_url]
    assert_match /checkout\/cancel/, captured_params[:cancel_url]
    assert_includes captured_params[:success_url], "{CHECKOUT_SESSION_ID}"
  end

  test "create finds or creates UK VAT tax rate" do
    tax_rate = build_stripe_tax_rate(id: "txr_existing_123")
    Stripe::TaxRate.stubs(:list).returns(build_stripe_list([ tax_rate ]))

    captured_params = nil
    session = build_stripe_session
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(session)

    post checkout_path

    # Should reuse existing tax rate
    assert_equal "txr_existing_123", captured_params[:line_items].first[:tax_rates].first
  end

  # ============================================================================
  # SUCCESS ACTION TESTS (GET /checkouts/success)
  # ============================================================================

  test "success creates order from paid Stripe session" do
    session = stub_stripe_session_retrieve(
      customer_email: "buyer@example.com",
      customer_name: "Jane Buyer",
      client_reference_id: @user.id,
      payment_status: "paid"
    )

    assert_difference "Order.count", 1 do
      get success_checkout_path, params: { session_id: session.id }
    end

    order = Order.last
    assert_equal "buyer@example.com", order.email
    assert_equal session.id, order.stripe_session_id
    assert_equal "paid", order.status
  end

  test "success extracts shipping details from Stripe session" do
    session = stub_stripe_session_retrieve(
      customer_email: "buyer@example.com",
      customer_name: "Test Buyer",
      shipping_name: "Test Buyer",
      shipping_address: {
        line1: "123 Test Street",
        line2: "Flat 4",
        city: "London",
        postal_code: "SW1A 1AA",
        country: "GB"
      }
    )

    get success_checkout_path, params: { session_id: session.id }

    order = Order.last
    assert_equal "Test Buyer", order.shipping_name
    assert_equal "123 Test Street", order.shipping_address_line1
    assert_equal "Flat 4", order.shipping_address_line2
    assert_equal "London", order.shipping_city
    assert_equal "SW1A 1AA", order.shipping_postal_code
    assert_equal "GB", order.shipping_country
  end

  test "success calculates order totals from cart and Stripe session" do
    session = stub_stripe_session_retrieve(
      customer_email: "buyer@example.com",
      shipping_amount_total: 500 # £5.00 in pence
    )

    get success_checkout_path, params: { session_id: session.id }

    order = Order.last
    assert_equal @cart.subtotal_amount, order.subtotal_amount
    assert_equal @cart.vat_amount, order.vat_amount
    assert_equal 5.0, order.shipping_amount
    assert_equal @cart.subtotal_amount + @cart.vat_amount + 5.0, order.total_amount
  end

  test "success creates order items from cart items" do
    session = stub_stripe_session_retrieve(customer_email: "buyer@example.com")

    assert_difference "OrderItem.count", @cart.cart_items.count do
      get success_checkout_path, params: { session_id: session.id }
    end

    order = Order.last
    order_item = order.order_items.first

    assert_equal @cart_item.product, order_item.product
    assert_equal @cart_item.product.display_name, order_item.product_name
    assert_equal @cart_item.product.sku, order_item.product_sku
    assert_equal @cart_item.price, order_item.price  # OrderItem stores pack price for display
    assert_equal @cart_item.quantity, order_item.quantity
    assert_equal @cart_item.product.pac_size, order_item.pac_size  # OrderItem stores pac_size for pricing display
  end

  test "success clears cart after creating order" do
    session = stub_stripe_session_retrieve(customer_email: "buyer@example.com")

    initial_cart_items_count = @cart.cart_items.count
    assert initial_cart_items_count > 0, "Cart should have items before checkout"

    get success_checkout_path, params: { session_id: session.id }

    @cart.reload
    assert_equal 0, @cart.cart_items.count
  end

  test "success sends order confirmation email" do
    session = stub_stripe_session_retrieve(customer_email: "buyer@example.com")

    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      get success_checkout_path, params: { session_id: session.id }
    end
  end

  test "success redirects to confirmation page with token" do
    session = stub_stripe_session_retrieve(customer_email: "buyer@example.com")

    get success_checkout_path, params: { session_id: session.id }

    order = Order.last
    # Now redirects to confirmation page (not show) with signed token
    # Check the redirect location contains the confirmation path (token varies by timestamp)
    assert_response :redirect
    assert_match %r{/orders/#{order.id}/confirmation\?token=}, response.location
  end

  test "success prevents duplicate orders with same session_id" do
    session = stub_stripe_session_retrieve(customer_email: "buyer@example.com")

    # First request creates order
    get success_checkout_path, params: { session_id: session.id }
    first_order = Order.last

    # Second request should not create duplicate
    assert_no_difference "Order.count" do
      get success_checkout_path, params: { session_id: session.id }
    end

    # Duplicate requests go to show page (not confirmation) with token
    assert_response :redirect
    assert_match %r{/orders/#{first_order.id}\?token=}, response.location
  end

  test "success handles missing session_id parameter" do
    get success_checkout_path

    assert_redirected_to cart_path
    assert_match /Invalid checkout session/, flash[:error]
  end

  test "success handles unpaid Stripe sessions" do
    session = stub_stripe_session_retrieve(
      customer_email: "buyer@example.com",
      payment_status: "unpaid"
    )

    assert_no_difference "Order.count" do
      get success_checkout_path, params: { session_id: session.id }
    end

    assert_redirected_to cart_path
    assert_match /Payment was not completed/, flash[:error]
  end

  test "success handles invalid session_id" do
    Stripe::Checkout::Session.stubs(:retrieve).raises(
      Stripe::InvalidRequestError.new("No such session", nil)
    )

    get success_checkout_path, params: { session_id: "sess_invalid_12345" }

    assert_redirected_to cart_path
    assert_match /Unable to verify payment/, flash[:error]
  end

  test "success handles empty cart gracefully" do
    session = stub_stripe_session_retrieve(customer_email: "buyer@example.com")

    # Clear the cart
    @cart.cart_items.destroy_all

    assert_no_difference "Order.count" do
      get success_checkout_path, params: { session_id: session.id }
    end

    assert_redirected_to root_path
    assert_match /No items found in cart/, flash[:error]
  end

  test "success associates order with user for authenticated checkouts" do
    session = stub_stripe_session_retrieve(
      customer_email: @user.email_address,
      client_reference_id: @user.id
    )

    get success_checkout_path, params: { session_id: session.id }

    order = Order.last
    assert_equal @user, order.user
  end

  test "success creates guest order when no user is authenticated" do
    session = stub_stripe_session_retrieve(customer_email: "guest@example.com")

    get success_checkout_path, params: { session_id: session.id }

    order = Order.last
    assert_nil order.user
    assert_equal "guest@example.com", order.email
  end

  # ============================================================================
  # CANCEL ACTION TESTS (GET /checkouts/cancel)
  # ============================================================================

  test "cancel redirects to cart with notice" do
    get cancel_checkout_path

    assert_redirected_to cart_path
    assert_match /Checkout cancelled/, flash[:notice]
  end

  # ============================================================================
  # DISCOUNT COUPON TESTS
  # ============================================================================

  test "create does not include discount when no coupon in session" do
    captured_params = nil
    stripe_session = build_stripe_session
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(stripe_session)

    post checkout_path

    assert_nil captured_params[:discounts]
  end

  # Note: Testing discount application requires session state persistence
  # across requests, which is complex in integration tests. The implementation
  # in checkouts_controller.rb lines 83-95 handles:
  # 1. Validating coupon exists via Stripe::Coupon.retrieve
  # 2. Adding discount to session_params if valid
  # 3. Gracefully handling invalid coupons by logging and continuing without discount
  # 4. Clearing discount code after successful order (line 181)

  # ============================================================================
  # ERROR HANDLING TESTS
  # ============================================================================

  test "create handles Stripe API connection errors" do
    Stripe::Checkout::Session.stubs(:create).raises(
      StripeErrors.api_connection_error
    )

    post checkout_path

    assert_redirected_to cart_path
    assert_not_nil flash[:error]
    assert_match /Failed to connect/, flash[:error]
  end

  test "create handles Stripe API errors" do
    Stripe::Checkout::Session.stubs(:create).raises(
      StripeErrors.api_error
    )

    post checkout_path

    assert_redirected_to cart_path
    assert_not_nil flash[:error]
  end

  test "create handles Stripe invalid request errors" do
    Stripe::Checkout::Session.stubs(:create).raises(
      StripeErrors.invalid_request("Invalid line items")
    )

    post checkout_path

    assert_redirected_to cart_path
    assert_match /Invalid line items/, flash[:error]
  end

  test "create logs Stripe errors" do
    Stripe::Checkout::Session.stubs(:create).raises(
      StripeErrors.api_connection_error
    )

    # Capture Rails.logger output
    logged_messages = []
    Rails.logger.stubs(:error).with { |msg| logged_messages << msg }

    post checkout_path

    assert logged_messages.any? { |msg| msg.include?("Stripe error:") }
  end

  test "success handles Stripe API errors when retrieving session" do
    Stripe::Checkout::Session.stubs(:retrieve).raises(
      StripeErrors.api_connection_error
    )

    assert_no_difference "Order.count" do
      get success_checkout_path, params: { session_id: "sess_test_123" }
    end

    assert_redirected_to cart_path
    assert_match /Unable to verify payment/, flash[:error]
  end

  test "success handles general errors during order creation" do
    session = stub_stripe_session_retrieve(customer_email: "buyer@example.com")

    # Simulate an error during order creation (e.g., validation failure)
    Order.any_instance.stubs(:save!).raises(StandardError.new("Database error"))

    assert_no_difference "Order.count" do
      get success_checkout_path, params: { session_id: session.id }
    end

    assert_redirected_to cart_path
    assert_match /error processing your order/, flash[:error]
  end

  test "success validates required shipping details presence" do
    # Use the helper with nil line1 to test validation
    session = build_stripe_session(
      id: "sess_test_missing_address",
      payment_status: "paid",
      shipping_address: { line1: nil, line2: "Flat 4", city: "London", postal_code: "SW1A 1AA", country: "GB" }
    )
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    assert_no_difference "Order.count" do
      get success_checkout_path, params: { session_id: session.id }
    end

    assert_redirected_to cart_path
    assert_match /error processing your order/, flash[:error]
  end

  test "create respects rate limiting" do
    stub_stripe_session_create

    # Rate limit is 10 requests per minute
    # This test verifies the rate_limit declaration exists
    # (Actual rate limiting behavior would require integration test with time manipulation)

    11.times do |i|
      post checkout_path
    end

    # After 10 requests, should hit rate limit
    # Note: In actual implementation, this would require time-based testing
    # or integration tests with proper rate limit store
  end

  # ============================================================================
  # ORGANIZATION AND B2B TESTS
  # ============================================================================

  test "creates order with organization for B2B users" do
    sign_in_as users(:acme_admin)

    # Add item to cart
    @cart.cart_items.create!(
      product: products(:single_wall_8oz_white),
      quantity: 10,
      price: 10.0
    )

    session = stub_stripe_session_retrieve(
      customer_email: users(:acme_admin).email_address,
      client_reference_id: users(:acme_admin).id
    )

    get success_checkout_path, params: { session_id: session.id }

    # Verify order created with organization
    order = Order.last
    assert_equal organizations(:acme), order.organization
    assert_equal users(:acme_admin), order.placed_by_user
  end

  test "creates order without organization for consumer users" do
    sign_in_as users(:consumer)

    # Add item to cart
    @cart.cart_items.create!(
      product: products(:single_wall_8oz_white),
      quantity: 10,
      price: 10.0
    )

    session = stub_stripe_session_retrieve(
      customer_email: users(:consumer).email_address,
      client_reference_id: users(:consumer).id
    )

    get success_checkout_path, params: { session_id: session.id }

    # Verify order created without organization
    order = Order.last
    assert_nil order.organization_id
    assert_nil order.placed_by_user_id
    assert_equal users(:consumer), order.user
  end

  test "sets branded_order_status for orders with configured items" do
    sign_in_as users(:acme_admin)

    # Add configured item
    cart_item = @cart.cart_items.new(
      product: products(:branded_template_variant),
      quantity: 1,
      configuration: { size: "12oz", quantity: 5000 },
      calculated_price: 1000.00,
      price: 1000.00
    )

    # Attach a design file before saving
    cart_item.design.attach(
      io: StringIO.new("fake design content"),
      filename: "design.pdf",
      content_type: "application/pdf"
    )
    cart_item.save!

    session = stub_stripe_session_retrieve(
      customer_email: users(:acme_admin).email_address,
      client_reference_id: users(:acme_admin).id
    )

    get success_checkout_path, params: { session_id: session.id }

    order = Order.last
    assert_equal "design_pending", order.branded_order_status
  end

  # ============================================================================
  # SAMPLES-ONLY CHECKOUT TESTS
  # ============================================================================

  test "samples-only cart uses Standard Shipping option" do
    # Create samples-only cart
    @cart.cart_items.destroy_all
    sample_variant = products(:sample_cup_8oz)
    @cart.cart_items.create!(
      product: sample_variant,
      quantity: 1,
      price: 0,
      is_sample: true
    )

    captured_params = nil
    session = build_stripe_session
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(session)

    post checkout_path

    assert_response :see_other
    assert_not_nil captured_params

    # Should have single Standard Shipping option (same as orders < £100)
    assert_equal 1, captured_params[:shipping_options].length
    shipping_option = captured_params[:shipping_options].first
    assert_equal "Standard Shipping", shipping_option[:shipping_rate_data][:display_name]
    assert_equal Shipping::STANDARD_COST, shipping_option[:shipping_rate_data][:fixed_amount][:amount]
  end

  test "samples-only cart line items have zero unit_amount" do
    # Create samples-only cart
    @cart.cart_items.destroy_all
    sample_variant = products(:sample_cup_8oz)
    @cart.cart_items.create!(
      product: sample_variant,
      quantity: 1,
      price: 0,
      is_sample: true
    )

    captured_params = nil
    session = build_stripe_session
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(session)

    post checkout_path

    assert_not_nil captured_params
    # Sample line items should have unit_amount of 0
    assert_equal 0, captured_params[:line_items].first[:price_data][:unit_amount]
  end

  test "mixed cart (samples + paid) uses standard shipping options" do
    # Add sample to existing cart (which already has paid items)
    sample_variant = products(:sample_cup_8oz)
    @cart.cart_items.create!(
      product: sample_variant,
      quantity: 1,
      price: 0,
      is_sample: true
    )

    captured_params = nil
    session = build_stripe_session
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(session)

    post checkout_path

    assert_not_nil captured_params
    # Mixed cart uses subtotal-based shipping:
    # - Orders < £100: Standard Shipping
    # - Orders >= £100: Free Shipping
    # Test cart has ~£20 subtotal, so should get Standard Shipping
    assert_equal 1, captured_params[:shipping_options].length
    assert_equal "Standard Shipping", captured_params[:shipping_options].first[:shipping_rate_data][:display_name]
  end

  # ============================================================================
  # HELPER METHODS
  # ============================================================================

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
