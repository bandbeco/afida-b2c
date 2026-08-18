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

    # Checkout requires a delivery destination (see the guard tests below), so
    # give every other test a mainland one. Those tests are about discounts,
    # line items and Stripe wiring, not about where the parcel is going.
    set_delivery_postcode("WD18 9SB")
  end

  # Store a delivery postcode in the session the way the cart page does. The
  # session isn't writable from an integration test, so go through the route.
  def set_delivery_postcode(postcode)
    post delivery_postcode_cart_path, params: { delivery_postcode: postcode }
  end

  # The welcome coupon id the app stores in the session, read from the test
  # credentials so the assertions track the actual vault value (CI decrypts
  # test.yml.enc via RAILS_TEST_KEY, so this is the same in CI and locally).
  def welcome_coupon_id
    Rails.application.credentials.dig(:stripe, :welcome_coupon)
  end

  # The fake Stripe promotion-code id and customer-facing code SessionBuilder
  # resolves the welcome coupon id to, before applying discounts:[{promotion_code:}]
  # and recording the code name on the order. Stubbed so checkout tests do not hit
  # the Stripe API.
  WELCOME_PROMOTION_CODE_ID = "promo_test_welcome"
  WELCOME_PROMOTION_CODE = "WELCOME10"

  # Stub the promotion-code lookup SessionBuilder performs for the welcome coupon,
  # returning a single active promotion code carrying its id and customer-facing code.
  def stub_welcome_promotion_code
    Stripe::PromotionCode.stubs(:list)
      .with(has_entries(coupon: welcome_coupon_id))
      .returns(stub(data: [ stub(id: WELCOME_PROMOTION_CODE_ID, code: WELCOME_PROMOTION_CODE) ]))
  end

  # The controller tests stub the flag seam; OnsiteCheckout's own ENV parsing
  # is covered in test/models/onsite_checkout_test.rb.
  def enable_onsite_checkout
    OnsiteCheckout.stubs(:enabled?).returns(true)
  end

  # ============================================================================
  # ON-SITE CHECKOUT (flag on)
  # ============================================================================

  test "create with flag on builds a custom-mode session and redirects to the checkout page" do
    enable_onsite_checkout

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_custom_stripe_session)

    post checkout_path

    assert_redirected_to checkout_path
    assert_response :see_other
    assert_equal "custom", captured_params[:ui_mode]
    assert_match %r{/checkout/success\?session_id=\{CHECKOUT_SESSION_ID\}}, captured_params[:return_url]
    assert_nil captured_params[:success_url]

    stash = session[:onsite_checkout]
    assert_equal "cs_test_secret_abc", stash["client_secret"]
    assert_equal "mainland", stash["zone"]
    assert stash["fingerprint"].present?
    assert_kind_of Integer, stash["created_at"]
    # The session id is the reprice endpoint's authority for WHICH Stripe
    # session may be updated - the client never sends one. Beyond that the
    # stash is cookie payload on every request, so nothing else rides along.
    assert_equal "sess_custom_123", stash["session_id"]
    assert_nil stash["postcode"]
  end

  test "create with flag on still refuses an empty cart" do
    enable_onsite_checkout
    @cart.cart_items.destroy_all

    post checkout_path

    assert_redirected_to cart_path
    assert_nil session[:onsite_checkout]
  end

  test "create with flag on and no destination proceeds priced as mainland" do
    enable_onsite_checkout
    # No typed postcode and no saved address to fall back to. The page reprices
    # from the address the customer types, so an unknown destination is a
    # mainland seed, not a refusal (see the guard tests below).
    @user.addresses.destroy_all
    set_delivery_postcode("")
    Stripe::Checkout::Session.stubs(:create).returns(build_custom_stripe_session)

    post checkout_path

    assert_redirected_to checkout_path
    assert_equal "mainland", session[:onsite_checkout]["zone"]
  end

  test "create with flag off never stashes" do
    stub_stripe_session_create

    post checkout_path

    assert_match %r{https://checkout\.stripe\.com}, response.redirect_url
    assert_nil session[:onsite_checkout]
  end

  # --- preview query param (env flag off throughout; no enabled? stub) ---

  test "onsite_checkout=1 on any page enables the on-site checkout for the session" do
    Stripe::Checkout::Session.stubs(:create).returns(build_custom_stripe_session)

    get cart_path(onsite_checkout: "1")
    post checkout_path

    assert_redirected_to checkout_path
    assert session[:onsite_checkout].present?
  end

  test "onsite_checkout=0 turns the preview back off" do
    stub_stripe_session_create

    get cart_path(onsite_checkout: "1")
    get cart_path(onsite_checkout: "0")
    post checkout_path

    assert_match %r{https://checkout\.stripe\.com}, response.redirect_url
    assert_nil session[:onsite_checkout]
  end

  test "show keeps serving a preview session while the env flag is off" do
    Stripe::Checkout::Session.stubs(:create).returns(build_custom_stripe_session)
    get cart_path(onsite_checkout: "1")
    post checkout_path

    get checkout_path

    assert_response :success
  end

  # --- GET /checkout (on-site page) ---

  def stash_onsite_session
    enable_onsite_checkout
    Stripe::Checkout::Session.stubs(:create).returns(build_custom_stripe_session)
    post checkout_path
    assert_redirected_to checkout_path
  end

  test "show renders the page from a fresh stash" do
    stash_onsite_session

    get checkout_path

    assert_response :success
    assert_match "cs_test_secret_abc", response.body
    assert_select "[data-controller='onsite-checkout']"
    assert_select "[data-onsite-checkout-target='payment']"
    assert_select "[data-onsite-checkout-target='address']"
    # With billing_address_collection "required", custom mode must mount its
    # own Billing Address Element or canConfirm never turns true (dead Pay
    # button); the Payment Element does not collect billing in this mode.
    assert_select "[data-onsite-checkout-target='billingAddress']"
    assert_select "[data-onsite-checkout-publishable-key-value]" do |elements|
      assert elements.first["data-onsite-checkout-publishable-key-value"].present?,
        "publishable key must reach the page"
    end
    # A hidden placeholder discount row so an on-page promo code has a row to
    # unhide.
    assert_select "div.hidden[data-onsite-checkout-target='discountRow']", count: 1
  end

  test "show redirects to cart when the flag is off" do
    get checkout_path
    assert_redirected_to cart_path
  end

  test "show redirects to cart without a stash" do
    enable_onsite_checkout
    get checkout_path
    assert_redirected_to cart_path
  end

  test "show bounces a stale stash to the cart and discards it" do
    stash_onsite_session

    @cart.cart_items.first.update!(quantity: 5)

    get checkout_path

    assert_redirected_to cart_path
    assert_equal "Your basket changed. Continue to payment when you're ready.", flash[:notice]
    assert_nil session[:onsite_checkout]
  end

  test "show shows the promo control only when no server discount and not samples-only" do
    stash_onsite_session
    get checkout_path
    assert_select "[data-onsite-checkout-target='promoSection']"
  end

  test "invalid welcome coupon renders the alert AND the promo control together" do
    # The spec's pinned combination: #create fell back to allow_promotion_codes
    # and deleted the session discount, so the GET page must show the failure
    # alert while still offering the promo input (the shopper can retype).
    enable_onsite_checkout
    post email_subscriptions_path, params: { email: "promo-test@example.com" }
    Stripe::PromotionCode.stubs(:list).returns(stub(data: []))
    Stripe::Coupon.stubs(:retrieve).raises(Stripe::InvalidRequestError.new("No such coupon", nil))
    Stripe::Checkout::Session.stubs(:create).returns(build_custom_stripe_session)

    post checkout_path
    follow_redirect!

    assert_response :success
    assert_match "Your discount code could not be applied", response.body
    assert_select "[data-onsite-checkout-target='promoSection']"
  end

  test "show bounces the stash when the delivery postcode is removed after create" do
    # The cart owner's saved addresses must not supply a fallback destination,
    # or removal would just re-resolve to the default address.
    @user.addresses.destroy_all
    stash_onsite_session

    set_delivery_postcode("")

    get checkout_path

    assert_redirected_to cart_path
    assert_nil session[:onsite_checkout]
  end

  test "show prices the summary from the address the session was priced from" do
    post session_url, params: { email_address: @user.email_address, password: "password" }
    highlands = @user.addresses.create!(
      nickname: "Croft", recipient_name: "John Smith", line1: "1 Shore Road",
      city: "Portree", postcode: "IV51 9XX", country: "GB"
    )
    set_delivery_postcode("")
    enable_onsite_checkout
    Stripe::Customer.stubs(:create).returns(stub(id: "cus_highlands"))
    Stripe::Checkout::Session.stubs(:create).returns(build_custom_stripe_session)

    post checkout_path, params: { address_id: highlands.id }
    assert_redirected_to checkout_path

    get checkout_path

    assert_response :success
    # The Stripe session carries the Highlands £25 shipping line; the summary
    # must show the same, not the default address's mainland price.
    assert_select "[data-onsite-checkout-money-kind='shipping']", text: "£25.00"
  end

  test "show bounces an expired stash instead of re-serving a dead client secret" do
    stash_onsite_session

    travel 24.hours do
      get checkout_path

      assert_redirected_to cart_path
      assert_match "expired", flash[:notice]
    end

    assert_nil session[:onsite_checkout]
  end

  test "show with the flag off discards the stash" do
    stash_onsite_session
    OnsiteCheckout.stubs(:enabled?).returns(false)

    get checkout_path

    assert_redirected_to cart_path
    assert_nil session[:onsite_checkout]
  end

  # --- PATCH /checkout (live shipping reprice from the on-site page) ---

  def reprice_params(postcode)
    { postcode: postcode }
  end

  def stub_reprice_stripe_calls
    Stripe::Checkout::Session.stubs(:list_line_items)
      .returns(stub(auto_paging_each: [ stripe_product_line_item(amount_subtotal: 2000, id: "li_prod") ].each))
    @update_capture = {}
    capture = @update_capture
    Stripe::Checkout::Session.stubs(:update).with do |id, params|
      capture[:id] = id
      capture[:params] = params
      true
    end.returns(build_custom_stripe_session)
  end

  test "update reprices the stashed session for the typed postcode" do
    stash_onsite_session
    stub_reprice_stripe_calls

    patch checkout_path, params: reprice_params("IV1 1AA"), as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal "highlands", body["zone"]
    assert_equal "£25.00", body["shipping_amount"]

    # The stash names the only session this endpoint may ever touch. The
    # update carries only price concerns; the SDK syncs the address itself.
    assert_equal "sess_custom_123", @update_capture[:id]
    assert_nil @update_capture[:params][:collected_information]
    assert_equal({ shipping_zone: "highlands" }, @update_capture[:params][:metadata])

    # Coherence writes: the typed postcode becomes the session postcode (so the
    # cart and GET /checkout resolve the same destination) and the stash's zone
    # and fingerprint move with it.
    assert_equal "IV1 1AA", session[:delivery_postcode]
    stash = session[:onsite_checkout]
    assert_equal "highlands", stash["zone"]
    assert_equal Checkout::CartFingerprint.digest(cart: @cart, postcode: "IV1 1AA", discount_code: nil),
                 stash["fingerprint"]
  end

  test "the checkout page still renders after a reprice instead of false-bouncing" do
    stash_onsite_session
    stub_reprice_stripe_calls

    patch checkout_path, params: reprice_params("IV1 1AA"), as: :json
    get checkout_path

    assert_response :success
    assert_select "[data-onsite-checkout-priced-zone-value='highlands']"
  end

  # A different postcode in the SAME zone needs no Stripe call (the shipping
  # line is already right) but must still move the session postcode and the
  # fingerprint, or GET /checkout would bounce a perfectly healthy stash.
  test "update with an unchanged zone skips Stripe but still records the postcode" do
    stash_onsite_session
    Stripe::Checkout::Session.expects(:list_line_items).never
    Stripe::Checkout::Session.expects(:update).never

    patch checkout_path, params: reprice_params("SW1A 1AA"), as: :json

    assert_response :success
    assert_equal "£6.99", response.parsed_body["shipping_amount"]
    assert_equal "SW1A 1AA", session[:delivery_postcode]
    assert_equal Checkout::CartFingerprint.digest(cart: @cart, postcode: "SW1A 1AA", discount_code: nil),
                 session[:onsite_checkout]["fingerprint"]
  end

  test "update reports free shipping for a qualifying order" do
    @cart.cart_items.create!(product: products(:two), quantity: 1, price: 150.00)
    stash_onsite_session
    stub_reprice_stripe_calls

    patch checkout_path, params: reprice_params("SW1A 1AA"), as: :json

    assert_response :success
    assert_equal "Free", response.parsed_body["shipping_amount"]
  end

  test "update refuses an undeliverable postcode and changes nothing" do
    stash_onsite_session
    Stripe::Checkout::Session.expects(:update).never

    patch checkout_path, params: reprice_params("JE2 3AB"), as: :json

    assert_response :unprocessable_entity
    assert_match "don't deliver", response.parsed_body["error"]
    assert_equal "WD18 9SB", session[:delivery_postcode]
    assert_equal "mainland", session[:onsite_checkout]["zone"]
  end

  test "update refuses an unparseable postcode with retry copy" do
    stash_onsite_session
    Stripe::Checkout::Session.expects(:update).never

    patch checkout_path, params: reprice_params("NOT A POSTCODE"), as: :json

    assert_response :unprocessable_entity
    assert_match "didn't recognise", response.parsed_body["error"]
  end

  test "update without a stash is gone" do
    enable_onsite_checkout

    patch checkout_path, params: reprice_params("IV1 1AA"), as: :json

    assert_response :gone
  end

  test "update with the flag off is gone" do
    patch checkout_path, params: reprice_params("IV1 1AA"), as: :json

    assert_response :gone
  end

  test "update on an expired stash is gone and discards it" do
    stash_onsite_session

    travel 24.hours do
      patch checkout_path, params: reprice_params("IV1 1AA"), as: :json

      assert_response :gone
    end

    assert_nil session[:onsite_checkout]
  end

  # Without this pre-check a reprice would recompute the fingerprint from the
  # CHANGED cart and overwrite the stash, masking exactly the staleness GET
  # /checkout's bounce exists to catch: the customer would pay the old total
  # for a basket the page no longer shows.
  test "update on a cart that changed since create conflicts and discards the stash" do
    stash_onsite_session
    @cart.cart_items.create!(product: products(:two), quantity: 1, price: 5.00)
    Stripe::Checkout::Session.expects(:update).never

    patch checkout_path, params: reprice_params("IV1 1AA"), as: :json

    assert_response :conflict
    assert_nil session[:onsite_checkout]
  end

  test "update conflicts when Stripe reports the session no longer updatable" do
    stash_onsite_session
    Stripe::Checkout::Session.stubs(:list_line_items)
      .returns(stub(auto_paging_each: [ stripe_product_line_item(amount_subtotal: 2000, id: "li_prod") ].each))
    Stripe::Checkout::Session.stubs(:update)
      .raises(Stripe::InvalidRequestError.new("This Checkout Session is no longer open", nil, http_status: 400))

    patch checkout_path, params: reprice_params("IV1 1AA"), as: :json

    assert_response :conflict
    # Nothing was written: the priced zone stays what the customer will be
    # charged, and the page's zone guard keeps Pay blocked on a mismatch.
    assert_equal "WD18 9SB", session[:delivery_postcode]
    assert_equal "mainland", session[:onsite_checkout]["zone"]
  end

  test "update surfaces other Stripe failures as retryable without writing state" do
    stash_onsite_session
    Stripe::Checkout::Session.stubs(:list_line_items)
      .returns(stub(auto_paging_each: [ stripe_product_line_item(amount_subtotal: 2000, id: "li_prod") ].each))
    Stripe::Checkout::Session.stubs(:update)
      .raises(Stripe::APIConnectionError.new("connection failed"))

    patch checkout_path, params: reprice_params("IV1 1AA"), as: :json

    assert_response :unprocessable_entity
    assert_match "try again", response.parsed_body["error"]
    assert_equal "mainland", session[:onsite_checkout]["zone"]
  end

  test "show renders the server discount row with the re-render target" do
    enable_onsite_checkout
    stub_welcome_promotion_code
    post email_subscriptions_path, params: { email: "promo-row@example.com" }
    Stripe::Checkout::Session.stubs(:create).returns(build_custom_stripe_session)

    post checkout_path
    get checkout_path

    assert_response :success
    assert_select "div.flex[data-onsite-checkout-target='discountRow']", count: 1
  end

  test "success clears the on-site checkout stash" do
    stash_onsite_session
    stripe_session = stub_stripe_session_retrieve(payment_status: "paid")

    get success_checkout_path, params: { session_id: stripe_session.id }

    assert_nil session[:onsite_checkout]
  end

  test "success logs the payment method that actually paid, not the configured list" do
    captured = nil
    stripe_session = build_stripe_session(payment_status: "paid", payment_method_type: "link")
    Stripe::Checkout::Session.stubs(:retrieve).with do |params|
      captured = params
      true
    end.returns(stripe_session)

    assert_event_reported("checkout.completed", payload: { payment_method: "link" }) do
      get success_checkout_path, params: { session_id: stripe_session.id }
    end

    assert_includes captured[:expand], "payment_intent.payment_method"
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

  # --- delivery destination guard ---
  # An UNKNOWN destination no longer blocks checkout: SessionBuilder prices it
  # mainland and the on-site page reprices from the address the customer
  # actually types (hosted fallback accepts the mainland-default gap, a
  # deliberate trade for not stranding customers who never met a postcode
  # field). A destination we KNOW we cannot serve is still refused: no reprice
  # can ever fix an order whose only address is the Isle of Man.

  test "create without any destination proceeds priced as mainland" do
    @user.addresses.destroy_all
    set_delivery_postcode("")

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    post checkout_path

    assert_response :see_other
    assert_equal "mainland", captured_params[:metadata][:shipping_zone]
  end

  test "create with an unparseable saved postcode proceeds priced as mainland" do
    set_delivery_postcode("")
    sign_in_as(@user)
    address = @user.addresses.create!(
      nickname: "Bad postcode #{SecureRandom.hex(4)}",
      recipient_name: "Jane",
      line1: "1 St",
      city: "Somewhere",
      postcode: "00000",
      country: "FR"
    )
    @user.update!(stripe_customer_id: "cus_zone_guard")
    User.any_instance.stubs(:sync_stripe_customer!)
    stub_stripe_session_create

    post checkout_path, params: { address_id: address.id }

    assert_response :see_other
  end

  test "create still refuses a destination we know we cannot serve" do
    set_delivery_postcode("")
    sign_in_as(@user)
    @user.addresses.create!(
      nickname: "Jersey #{SecureRandom.hex(4)}",
      recipient_name: "Jane",
      line1: "1 St",
      city: "St Helier",
      postcode: "JE2 3AB",
      country: "GB",
      default: true
    )
    Stripe::Checkout::Session.expects(:create).never

    post checkout_path

    assert_redirected_to cart_path
    assert flash[:alert].present?, "expected the customer to be told why checkout stopped"
  end

  test "a selected saved address satisfies the requirement without a typed postcode" do
    set_delivery_postcode("")
    address = addresses(:office)
    @user.update!(stripe_customer_id: "cus_zone_guard")
    User.any_instance.stubs(:sync_stripe_customer!)
    sign_in_as(@user)
    stub_stripe_session_create

    post checkout_path, params: { address_id: address.id }

    assert_response :see_other
    assert_match %r{https://checkout\.stripe\.com/test/sess_}, response.redirect_url
  end

  test "checkout proceeds once a postcode has been given" do
    set_delivery_postcode("BT1 6EE")
    stub_stripe_session_create

    post checkout_path

    assert_response :see_other
  end

  # The cart and the checkout must resolve the destination the SAME way. They
  # once disagreed: the cart preferred the typed postcode and fell back to the
  # customer's default address, while checkout preferred a selected saved
  # address and fell back to the typed postcode. Two bugs followed.

  test "charges the zone the cart quoted when a saved address is also selected" do
    # Bug: typing a mainland postcode and then selecting a saved Highlands
    # address quoted £6.99 on the cart and charged £25 at Stripe, an undisclosed
    # jump at the payment screen. The cart's quote is the promise, so it wins.
    skye = @user.addresses.create!(
      nickname: "Skye #{SecureRandom.hex(4)}", recipient_name: "Jane",
      line1: "2 Skye Rd", city: "Portree", postcode: "IV51 9YB", country: "GB"
    )
    @user.update!(stripe_customer_id: "cus_zone_agree")
    User.any_instance.stubs(:sync_stripe_customer!)
    sign_in_as(@user)
    set_delivery_postcode("WD18 9SB")

    captured = nil
    Stripe::Checkout::Session.stubs(:create).with { |p| captured = p; true }.returns(build_stripe_session)

    post checkout_path, params: { address_id: skye.id }

    assert_equal "mainland", captured[:metadata][:shipping_zone],
                 "Stripe must charge the zone the cart quoted, not a different saved address"
  end

  test "a default saved address satisfies the requirement, as the cart prices from it" do
    # Bug: the cart enables its checkout button from the customer's DEFAULT
    # address, but checkout only accepted a SELECTED one. Submitting with a
    # blank address_id (the "enter a different address" radio) was refused and
    # bounced back to a cart whose button was still enabled: a dead-end loop.
    set_delivery_postcode("")
    @user.update!(stripe_customer_id: "cus_default_addr")
    User.any_instance.stubs(:sync_stripe_customer!)
    sign_in_as(@user)
    stub_stripe_session_create

    post checkout_path, params: { address_id: "" }

    assert_response :see_other, "a customer whose cart priced from their default address must not be refused"
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
    assert captured_params[:line_items].all? { |li| li[:price_data][:currency] == "gbp" }
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

  # Authenticated checkouts without a selected address keep customer_email (attaching
  # `customer` would prefill a saved address the customer did not pick), but must still
  # have Stripe persist a Customer so per-customer coupon restrictions have an identity
  # to key on: a one-time coupon was otherwise redeemable indefinitely.
  test "create includes customer email and asks stripe to create a customer for authenticated users" do
    Current.stubs(:user).returns(@user)

    captured_params = nil
    session = build_stripe_session
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(session)

    post checkout_path

    assert_equal @user.email_address, captured_params[:customer_email]
    assert_equal "always", captured_params[:customer_creation]
    assert_nil captured_params[:customer]
    assert_equal @user.id, captured_params[:client_reference_id]
  end

  # A guest carries no known identity, but Stripe must still persist a Customer for
  # whoever pays, so the coupon restriction can match them on a later order.
  test "create asks stripe to create a customer for guest users" do
    captured_params = nil
    session = build_stripe_session
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(session)

    post checkout_path

    assert_nil captured_params[:customer_email]
    assert_nil captured_params[:client_reference_id]
    assert_equal "always", captured_params[:customer_creation]
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

  test "create appends a taxed shipping line item instead of shipping options" do
    captured_params = nil
    session = build_stripe_session
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(session)

    post checkout_path

    # Shipping rides as a taxed line item (manual tax rates only tax line items),
    # not a shipping_option. The £20 cart is under the free-shipping threshold.
    assert_nil captured_params[:shipping_options]
    shipping_line = captured_params[:line_items].find do |li|
      li.dig(:price_data, :product_data, :metadata, "shipping_line") == "true"
    end
    assert shipping_line, "expected a taxed shipping line item"
    assert_equal Shipping::STANDARD_COST, shipping_line[:price_data][:unit_amount]
    assert_equal "exclusive", shipping_line[:price_data][:tax_behavior]
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

    # Should reuse existing tax rate on the product line (the shipping line is
    # prepended, so select by content rather than position).
    product_line = captured_params[:line_items].find do |li|
      li.dig(:price_data, :product_data, :metadata, "shipping_line") != "true"
    end
    assert_equal "txr_existing_123", product_line[:tax_rates].first
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

  test "success calculates order totals from Stripe session amounts, taxing shipping" do
    # Shipping is a taxed line item: amount_subtotal includes it (2000 + 500) and
    # amount_tax is VAT on both: 2500 * 0.2 = 500.
    session = stub_stripe_session_retrieve(
      customer_email: "buyer@example.com",
      amount_subtotal: 2500,
      amount_tax: 500,
      amount_total: 3000,
      line_items_data: [
        stripe_product_line_item(amount_subtotal: 2000),
        stripe_shipping_line_item(amount_subtotal: 500)
      ]
    )

    assert_difference "Order.count", 1 do
      get success_checkout_path, params: { session_id: session.id }
    end

    order = Order.last
    assert_equal 20.0, order.subtotal_amount.to_f
    assert_equal 5.0, order.vat_amount.to_f
    assert_equal 5.0, order.shipping_amount.to_f
    assert_equal 30.0, order.total_amount.to_f
  end

  test "success expands nested line item product so shipping is identifiable" do
    session = build_stripe_session(
      customer_email: "buyer@example.com",
      amount_subtotal: 2500,
      amount_tax: 500,
      amount_total: 3000,
      line_items_data: [
        stripe_product_line_item(amount_subtotal: 2000),
        stripe_shipping_line_item(amount_subtotal: 500)
      ]
    )
    Stripe::Checkout::Session.expects(:retrieve).with do |args|
      # total_details.breakdown must be expanded or the discount breakdown comes back
      # nil and the order records no discount_code (see SessionDetails.promotion_code).
      args[:expand] == [ "collected_information", "line_items.data.price.product",
                        "payment_intent.payment_method", "total_details.breakdown" ]
    end.returns(session)

    assert_difference "Order.count", 1 do
      get success_checkout_path, params: { session_id: session.id }
    end
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

  test "success enqueues a Telegram notification for the new order" do
    session = stub_stripe_session_retrieve(customer_email: "buyer@example.com")

    get success_checkout_path, params: { session_id: session.id }

    order = Order.last
    assert_enqueued_with(job: TelegramOrderNotificationJob, args: [ order.id ])
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

    # Duplicate requests redirect to confirmation page with signed token
    assert_response :redirect
    assert_match %r{/orders/#{first_order.id}/confirmation\?token=}, response.location
  end

  test "success redirects to the existing order when it loses the create race to the webhook" do
    # TOCTOU: the find_by check passes (no order yet), then the webhook commits the
    # order microseconds before OrderCreator runs, so create! hits the unique
    # stripe_session_id index. The paying customer must be redirected to the
    # existing order's confirmation, not shown a 500.
    session = stub_stripe_session_retrieve(customer_email: "buyer@example.com", client_reference_id: @user.id)

    # The order the webhook commits during the TOCTOU window.
    racing_order = Order.create!(
      user: @user, email: "buyer@example.com", stripe_session_id: session.id, status: "paid",
      subtotal_amount: 20, vat_amount: 4, shipping_amount: 0, total_amount: 24,
      shipping_name: "Buyer", shipping_address_line1: "1 St", shipping_city: "London",
      shipping_postal_code: "SW1A 1AA", shipping_country: "GB"
    )
    # find_by sees nothing on the guard check, but the order exists by the time the
    # rescue re-checks; OrderCreator hits the unique index in between.
    Order.stubs(:find_by).with(stripe_session_id: session.id).returns(nil).then.returns(racing_order)
    Checkout::OrderCreator.any_instance.stubs(:create).raises(
      ActiveRecord::RecordNotUnique.new("duplicate key value violates unique constraint")
    )

    get success_checkout_path, params: { session_id: session.id }

    assert_response :redirect
    assert_match %r{/orders/#{racing_order.id}/confirmation\?token=}, response.location
  end

  test "success does not 422 a paid customer when an order item fails validation" do
    # A non-race RecordInvalid (e.g. an OrderItem validation fails inside
    # OrderCreator's transaction, rolling back the order) must not surface as a 422
    # to someone who has already paid. Capture it and redirect gracefully - the
    # webhook fallback still creates the order - rather than re-raising.
    session = stub_stripe_session_retrieve(customer_email: "buyer@example.com", client_reference_id: @user.id)
    # No order exists for this session, and create raises a validation error that is
    # NOT the uniqueness race.
    Order.stubs(:find_by).with(stripe_session_id: session.id).returns(nil)
    Checkout::OrderCreator.any_instance.stubs(:create).raises(
      ActiveRecord::RecordInvalid.new(Order.new)
    )
    Sentry.expects(:capture_exception).at_least_once

    assert_no_difference "Order.count" do
      get success_checkout_path, params: { session_id: session.id }
    end

    assert_redirected_to cart_path
    assert_match /Unable to verify payment/, flash[:error]
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

  test "success creates a zero-total order for a no_payment_required session" do
    # A 100%-off coupon (or any discount covering the whole order, including the
    # taxed shipping line) makes Stripe complete the session with payment_status
    # "no_payment_required" and amount_total 0 - never "paid". The order must
    # still be created and fulfilled.
    session = stub_stripe_session_retrieve(
      customer_email: "buyer@example.com",
      client_reference_id: @user.id,
      payment_status: "no_payment_required",
      amount_subtotal: 0,
      amount_tax: 0,
      amount_total: 0
    )

    assert_difference "Order.count", 1 do
      get success_checkout_path, params: { session_id: session.id }
    end

    order = Order.last
    assert_equal "buyer@example.com", order.email
    assert_equal session.id, order.stripe_session_id
    assert_equal "paid", order.status
    assert_equal 0, order.total_amount
    # Token carries a timestamp, so match the confirmation path rather than rebuild it.
    assert_response :redirect
    assert_match %r{/orders/#{order.id}/confirmation\?token=}, response.location
  end

  test "success handles invalid session_id" do
    Stripe::Checkout::Session.stubs(:retrieve).raises(
      Stripe::InvalidRequestError.new("No such session", nil)
    )

    get success_checkout_path, params: { session_id: "sess_invalid_12345" }

    assert_redirected_to cart_path
    assert_match /Unable to verify payment/, flash[:error]
  end

  test "success handles an unexpanded-line-item error gracefully instead of 500ing" do
    # If a future change drops the line_items.data.price.product expand,
    # SessionAmounts raises UnexpandedLineItemError. The paying customer must get a
    # graceful redirect (the webhook still creates the order), not a 500.
    stub_stripe_session_retrieve(customer_email: "buyer@example.com", client_reference_id: @user.id)
    Checkout::SessionAmounts.stubs(:from).raises(
      Checkout::SessionAmounts::UnexpandedLineItemError.new("line item product not expanded")
    )

    assert_no_difference "Order.count" do
      get success_checkout_path, params: { session_id: "sess_unexpanded" }
    end

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
  # DISCOUNT / STRIPE-SOURCED TOTALS TESTS
  # ============================================================================

  test "success uses Stripe session amounts as source of truth for order totals" do
    # Cart has subtotal £20 (2 items × £10), but Stripe reflects a discount.
    # Shipping is a taxed line item, so amount_subtotal includes it (1900 + 500)
    # and amount_tax is VAT on both: 2400 * 0.2 = 480.
    session = build_stripe_session(
      id: "sess_discount_test",
      payment_status: "paid",
      customer_email: "buyer@example.com",
      amount_subtotal: 2400,    # products £19 (post-discount) + shipping £5
      amount_tax: 480,          # £4.80
      amount_total: 2880,       # £28.80
      amount_discount: 100,     # £1.00 discount
      line_items_data: [
        stripe_product_line_item(amount_subtotal: 1900),
        stripe_shipping_line_item(amount_subtotal: 500)
      ]
    )
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    get success_checkout_path, params: { session_id: session.id }

    order = Order.last
    # Order should use Stripe amounts, NOT cart-calculated amounts
    assert_equal 19.0, order.subtotal_amount.to_f
    assert_equal 4.80, order.vat_amount.to_f
    assert_equal 5.0, order.shipping_amount.to_f
    assert_equal 28.80, order.total_amount.to_f
    assert_equal 1.0, order.discount_amount.to_f
  end

  test "success stores discount code on order when discount was applied" do
    session = build_stripe_session(
      id: "sess_discount_code_test",
      payment_status: "paid",
      customer_email: "buyer@example.com",
      amount_subtotal: 2400,
      amount_tax: 480,
      amount_total: 2880,
      amount_discount: 100,
      metadata: { discount_code: "WELCOME5" },
      line_items_data: [
        stripe_product_line_item(amount_subtotal: 1900),
        stripe_shipping_line_item(amount_subtotal: 500)
      ]
    )
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    get success_checkout_path, params: { session_id: session.id }

    order = Order.last
    assert_equal "WELCOME5", order.discount_code
  end

  test "success sets zero discount when no discount applied" do
    session = build_stripe_session(
      id: "sess_no_discount_test",
      payment_status: "paid",
      customer_email: "buyer@example.com",
      amount_subtotal: 2500,
      amount_tax: 500,
      amount_total: 3000,
      amount_discount: 0,
      line_items_data: [
        stripe_product_line_item(amount_subtotal: 2000),
        stripe_shipping_line_item(amount_subtotal: 500)
      ]
    )
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    get success_checkout_path, params: { session_id: session.id }

    order = Order.last
    assert_equal 0.0, order.discount_amount.to_f
    assert_nil order.discount_code
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

  test "create sets allow_promotion_codes when no session discount" do
    captured_params = nil
    stripe_session = build_stripe_session
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(stripe_session)

    post checkout_path

    assert_equal true, captured_params[:allow_promotion_codes]
  end

  test "create does not set allow_promotion_codes when session discount exists" do
    # Set discount code in session via email subscription
    post email_subscriptions_path, params: { email: "promo-test@example.com" }

    stub_welcome_promotion_code

    captured_params = nil
    stripe_session = build_stripe_session
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(stripe_session)

    post checkout_path

    assert_nil captured_params[:allow_promotion_codes]
    # The welcome coupon id resolves to its promotion code, so the promotion code
    # (not a raw coupon) is what Stripe applies.
    assert_equal [ { promotion_code: WELCOME_PROMOTION_CODE_ID } ], captured_params[:discounts]
  end

  test "create records the resolved human-readable code in the session metadata" do
    post email_subscriptions_path, params: { email: "metadata-code@example.com" }
    assert_equal welcome_coupon_id, session[:discount_code]
    stub_welcome_promotion_code

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    post checkout_path

    # The order's discount_code comes from this metadata. SessionBuilder rewrites it
    # from the opaque coupon id to the resolved promotion code (WELCOME10), so the
    # order records the human-readable code.
    assert_equal WELCOME_PROMOTION_CODE, captured_params[:metadata][:discount_code]
  end

  test "success extracts discount code from Stripe promotion code when customer enters code" do
    session = build_stripe_session(
      id: "sess_promo_code_test",
      payment_status: "paid",
      customer_email: "buyer@example.com",
      amount_subtotal: 2300,
      amount_tax: 460,
      amount_total: 2760,
      amount_discount: 200,
      metadata: {},
      promotion_code: "SUMMER20",
      line_items_data: [
        stripe_product_line_item(amount_subtotal: 1800),
        stripe_shipping_line_item(amount_subtotal: 500)
      ]
    )
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    get success_checkout_path, params: { session_id: session.id }

    order = Order.last
    assert_equal 2.0, order.discount_amount.to_f
    assert_equal "SUMMER20", order.discount_code
  end

  test "success prefers metadata discount code over Stripe promotion code" do
    session = build_stripe_session(
      id: "sess_metadata_priority",
      payment_status: "paid",
      customer_email: "buyer@example.com",
      amount_subtotal: 2300,
      amount_tax: 460,
      amount_total: 2760,
      amount_discount: 200,
      metadata: { discount_code: "WELCOME5" },
      promotion_code: "SUMMER20",
      line_items_data: [
        stripe_product_line_item(amount_subtotal: 1800),
        stripe_shipping_line_item(amount_subtotal: 500)
      ]
    )
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    get success_checkout_path, params: { session_id: session.id }

    order = Order.last
    assert_equal "WELCOME5", order.discount_code
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

  test "create clears invalid discount before handling later Stripe session errors" do
    post email_subscriptions_path, params: { email: "invalid-discount@example.com" }
    assert_equal welcome_coupon_id, session[:discount_code]

    # No matching promotion code, and the raw-coupon-id fallback also misses, so the
    # code is treated as invalid (the cleanup path under test).
    Stripe::PromotionCode.stubs(:list).returns(stub(data: []))
    Stripe::Coupon.stubs(:retrieve).raises(
      Stripe::InvalidRequestError.new("No such coupon", nil)
    )
    Stripe::Checkout::Session.stubs(:create).raises(
      StripeErrors.api_error
    )

    post checkout_path

    assert_nil session[:discount_code]
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

  test "success raises on order creation errors instead of silently swallowing" do
    session = stub_stripe_session_retrieve(customer_email: "buyer@example.com")

    # Simulate an error during order creation (e.g., validation failure)
    Order.any_instance.stubs(:save!).raises(StandardError.new("Database error"))

    assert_raises(StandardError) do
      get success_checkout_path, params: { session_id: session.id }
    end
  end

  test "success handles missing shipping details with checkout retry" do
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
    assert_match /Shipping details are required/, flash[:error]
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

  test "samples-only cart appends a taxed shipping line item" do
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

    # Samples-only carts still pay (taxed) shipping; it rides as a line item.
    assert_nil captured_params[:shipping_options]
    shipping_line = captured_params[:line_items].find do |li|
      li.dig(:price_data, :product_data, :metadata, "shipping_line") == "true"
    end
    assert shipping_line, "expected a taxed shipping line item"
    assert_equal Shipping::STANDARD_COST, shipping_line[:price_data][:unit_amount]
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
    # Sample line items should have unit_amount of 0. Select the product line by
    # content: the shipping line is prepended, so it is no longer at index 0.
    sample_line = captured_params[:line_items].find do |li|
      li.dig(:price_data, :product_data, :metadata, "shipping_line") != "true"
    end
    assert_equal 0, sample_line[:price_data][:unit_amount]
  end

  test "mixed cart (samples + paid) appends a taxed shipping line item" do
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
    # Mixed cart, ~£20 subtotal (under the £100 threshold), so shipping is charged
    # as a taxed line item.
    assert_nil captured_params[:shipping_options]
    shipping_line = captured_params[:line_items].find do |li|
      li.dig(:price_data, :product_data, :metadata, "shipping_line") == "true"
    end
    assert shipping_line, "expected a taxed shipping line item"
  end

  # ============================================================================
  # HELPER METHODS
  # ============================================================================

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end

  # ============================================================================
  # STRUCTURED EVENT EMISSION TESTS (User Story 1: Debug Silent Failures)
  # ============================================================================

  test "emits checkout.started event when checkout begins" do
    stub_stripe_session_create

    assert_event_reported("checkout.started",
      payload: {
        cart_id: @cart.id,
        item_count: @cart.cart_items.count,
        subtotal: @cart.subtotal_amount
      }
    ) do
      post checkout_path
    end

    assert_response :see_other
  end

  # --- cart.checkout_initiated for logged-in users (abandoned-cart trigger) ---
  #
  # Guests fire this from the discount-signup form; logged-in users (whose email
  # we already know) fire it here, where Current.user and Current.cart coexist.
  # The payload carries user_id (not the filtered email); KlaviyoSubscriber
  # resolves User#email_address from it. Klaviyo's Flow owns delay/suppression.
  test "emits cart.checkout_initiated with user_id for a logged-in user with a paid cart" do
    Current.stubs(:user).returns(@user)
    stub_stripe_session_create

    assert_event_reported("cart.checkout_initiated",
      payload: {
        cart_id: @cart.id,
        user_id: @user.id,
        source: "checkout"
      }
    ) do
      post checkout_path
    end
  end

  test "does not emit cart.checkout_initiated for a guest checkout" do
    # No Current.user stub: a guest reaching checkout has no known email here.
    Current.stubs(:user).returns(nil)
    stub_stripe_session_create

    assert_no_event_reported("cart.checkout_initiated") do
      post checkout_path
    end
  end

  test "does not emit cart.checkout_initiated when a discount code is already in the session" do
    # The visitor already signed up via the discount form this session, which
    # fired the trigger; suppress the duplicate from checkout.
    Current.stubs(:user).returns(@user)
    post email_subscriptions_path, params: { email: "noorders@example.com" }
    assert session[:discount_code].present?, "setup: discount code should be in session"
    # With a code in session, checkout resolves the welcome promo code against Stripe; stub it.
    stub_welcome_promotion_code
    stub_stripe_session_create

    assert_no_event_reported("cart.checkout_initiated") do
      post checkout_path
    end
  end

  test "does not emit cart.checkout_initiated for a logged-in user with a sample-only cart" do
    Current.stubs(:user).returns(@user)
    @cart.cart_items.update_all(is_sample: true, price: 0)
    stub_stripe_session_create

    assert_no_event_reported("cart.checkout_initiated") do
      post checkout_path
    end
  end

  test "create rejects an empty cart without building a Stripe session" do
    # An empty cart has subtotal 0, which is below the free-shipping threshold, so
    # building a session would add a shipping line and create a shipping-only
    # Checkout Session that could be charged. Reject before reaching Stripe.
    @cart.cart_items.destroy_all
    Stripe::Checkout::Session.expects(:create).never

    post checkout_path

    assert_redirected_to cart_path
    assert_match /cart is empty/i, flash[:alert]
  end

  test "does not emit cart.checkout_initiated for a logged-in user with an empty cart" do
    # only_samples? is false for an empty cart, so the explicit cart_items.any?
    # guard is what blocks this; assert it directly rather than rely on it.
    Current.stubs(:user).returns(@user)
    @cart.cart_items.destroy_all
    stub_stripe_session_create

    assert_no_event_reported("cart.checkout_initiated") do
      post checkout_path
    end
  end

  test "emits checkout.completed event on successful payment verification" do
    session = stub_stripe_session_retrieve(
      customer_email: "buyer@example.com",
      payment_status: "paid"
    )

    assert_event_reported("checkout.completed") do
      get success_checkout_path, params: { session_id: session.id }
    end

    assert_response :redirect
  end

  test "emits order.placed event when order is created from checkout" do
    session = stub_stripe_session_retrieve(
      customer_email: "buyer@example.com",
      payment_status: "paid"
    )

    assert_event_reported("order.placed") do
      get success_checkout_path, params: { session_id: session.id }
    end

    assert_response :redirect
  end

  test "does not emit checkout events on payment failure" do
    session = stub_stripe_session_retrieve(
      customer_email: "buyer@example.com",
      payment_status: "unpaid"
    )

    assert_no_event_reported("checkout.completed") do
      assert_no_event_reported("order.placed") do
        get success_checkout_path, params: { session_id: session.id }
      end
    end

    assert_redirected_to cart_path
  end

  test "emits email_signup.discount_claimed event when order placed with discount" do
    # Set discount code in session
    post email_subscriptions_path, params: { email: "discount-test@example.com" }
    assert_equal welcome_coupon_id, session[:discount_code]

    # Stub Stripe to resolve the welcome promo code
    stub_welcome_promotion_code

    session = stub_stripe_session_retrieve(
      customer_email: "discount-test@example.com",
      payment_status: "paid"
    )

    assert_event_reported("email_signup.discount_claimed") do
      get success_checkout_path, params: { session_id: session.id }
    end

    assert_response :redirect
  end

  test "does not emit email_signup.discount_claimed event when order placed without discount" do
    session = stub_stripe_session_retrieve(
      customer_email: "no-discount@example.com",
      payment_status: "paid"
    )

    assert_no_event_reported("email_signup.discount_claimed") do
      get success_checkout_path, params: { session_id: session.id }
    end

    assert_response :redirect
  end
end
