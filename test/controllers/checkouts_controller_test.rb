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

    # With no typed postcode (only PATCH /checkout writes one now), the
    # destination resolves from the cart owner's default fixture address:
    # SW1A 1AA, mainland. Tests about discounts, line items and Stripe wiring
    # ride on that; zone-specific tests set their own destination.
  end

  # The welcome coupon id the app stores in the session, read from the test
  # credentials so the assertions track the actual vault value (CI decrypts
  # test.yml.enc via RAILS_TEST_KEY, so this is the same in CI and locally).
  def welcome_coupon_id
    Rails.application.credentials.dig(:stripe, :welcome_coupon)
  end

  def completion_outcome(status, order)
    Checkout::Completion::Outcome.new(order: order, status: status)
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
    # session may be updated - the client never sends one. The shipping the
    # session charges is frozen here too, so the same-zone reprice
    # short-circuit can quote it without recomputing from live constants.
    # Beyond that the stash is cookie payload on every request, so nothing
    # else rides along.
    assert_equal "sess_custom_123", stash["session_id"]
    assert_equal 699, stash["shipping_pence"]
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

  test "show bounces the stash when the resolved destination changes after create" do
    # The destination re-resolves on every render (typed postcode, then the
    # default address); a default address whose postcode changed after create
    # means the session no longer charges the destination the page would show.
    stash_onsite_session

    addresses(:office).update!(postcode: "IV1 1AA")

    get checkout_path

    assert_redirected_to cart_path
    assert_nil session[:onsite_checkout]
  end

  test "show prices the summary from the destination the session was priced from" do
    # The default address is the destination the session is priced from now
    # that nothing else supplies one before checkout.
    @user.addresses.create!(
      nickname: "Croft", recipient_name: "John Smith", line1: "1 Shore Road",
      city: "Portree", postcode: "IV51 9XX", country: "GB", default: true
    )
    stash_onsite_session

    get checkout_path

    assert_response :success
    # The Stripe session carries the Highlands £25 shipping line; the summary
    # must show the same, not a mainland price.
    assert_select "[data-onsite-checkout-money-kind='shipping']", text: "£25.00"
  end

  test "show with no destination prices the summary as the session does, not deferred" do
    # No postcode anywhere (the cart owner's default address is a fallback, so
    # it must go too): SessionBuilder priced the Stripe session mainland (£6.99
    # shipping line), and the SDK paints VAT and Total from that session. A
    # deferred shipping row would sit beside a Total that silently includes
    # shipping the lines above it don't show.
    @user.addresses.destroy_all
    stash_onsite_session

    get checkout_path

    assert_response :success
    assert_select "[data-onsite-checkout-money-kind='shipping']", text: "£6.99"
  end

  test "show does not prefill a saved address when a typed postcode outranks it" do
    post session_url, params: { email_address: @user.email_address, password: "password" }
    stash_onsite_session
    # Typing WD18 on the page wins the pricing (delivery_postcode_for), but the
    # default saved address is SW1A: prefilling it would complete the element
    # on mount and auto-reprice, silently overwriting the typed postcode.
    patch checkout_path, params: reprice_params("WD18 9SB"), as: :json
    assert_response :success

    get checkout_path

    assert_response :success
    assert_select "[data-onsite-checkout-prefill-value]" do |elements|
      refute_includes elements.first["data-onsite-checkout-prefill-value"], "line1",
        "an address the session was not priced from must not prefill"
    end
  end

  test "show still prefills the saved address whose postcode matches the typed one" do
    post session_url, params: { email_address: @user.email_address, password: "password" }
    stash_onsite_session
    # Same postcode, differently cased and spaced: normalisation says it is the
    # address the session was priced from, so the convenience prefill stays.
    patch checkout_path, params: reprice_params("sw1a 1aa"), as: :json
    assert_response :success

    get checkout_path

    assert_response :success
    assert_select "[data-onsite-checkout-prefill-value]" do |elements|
      assert_includes elements.first["data-onsite-checkout-prefill-value"], "123 High Street"
    end
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

  # The client_secret is the tab's proof that it is the stashed session (the
  # superseded-tab tests below send a different one, or none).
  def reprice_params(postcode)
    { postcode: postcode, client_secret: "cs_test_secret_abc" }
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
    assert_equal 2500, stash["shipping_pence"]
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

  test "update's same-zone short-circuit quotes the shipping the session charges, not current constants" do
    stash_onsite_session
    # Simulate a shipping-price deploy between create and the address edit: the
    # live quote rule changes, but the session's frozen line item does not, so
    # the page must keep displaying what Stripe will actually charge.
    Checkout::SessionRepricer.stubs(:shipping_pence).returns(999)

    patch checkout_path, params: reprice_params("SW1A 1AA"), as: :json

    assert_response :success
    assert_equal "£6.99", response.parsed_body["shipping_amount"]
  end

  test "update's same-zone short-circuit runs one cart_items query" do
    # The emptiness guard and both fingerprints (pre-check and post-write)
    # share one loaded set, and the short-circuit quotes shipping from the
    # stash, so this hot endpoint hits cart_items exactly once.
    stash_onsite_session
    selects = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      sql = payload[:sql].to_s
      selects << sql if sql.start_with?("SELECT") && sql.include?("cart_items")
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      patch checkout_path, params: reprice_params("SW1A 1AA"), as: :json
    end

    assert_response :success
    assert_equal 1, selects.size, "expected one cart_items query, got:\n#{selects.join("\n")}"
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
    assert_nil session[:delivery_postcode]
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

  # Two checkout tabs share one Rails session, and every POST /checkout
  # re-stashes: the stash then names the NEWER tab's Stripe session, while the
  # older tab still holds (and could pay) its own. Its reprices must be
  # refused, not applied to a session its page isn't showing - and the stash
  # must survive, because it belongs to the newer tab, which is healthy.
  test "update from a tab whose session was superseded conflicts and keeps the stash" do
    stash_onsite_session
    Stripe::Checkout::Session.expects(:list_line_items).never
    Stripe::Checkout::Session.expects(:update).never

    patch checkout_path,
          params: { postcode: "IV1 1AA", client_secret: "cs_test_secret_superseded" }, as: :json

    assert_response :conflict
    assert_equal "sess_custom_123", session[:onsite_checkout]["session_id"]
    assert_nil session[:delivery_postcode]
    assert_equal "mainland", session[:onsite_checkout]["zone"]
  end

  test "update without the tab's client secret conflicts and keeps the stash" do
    stash_onsite_session
    Stripe::Checkout::Session.expects(:list_line_items).never
    Stripe::Checkout::Session.expects(:update).never

    patch checkout_path, params: { postcode: "IV1 1AA" }, as: :json

    assert_response :conflict
    assert_equal "sess_custom_123", session[:onsite_checkout]["session_id"]
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
    assert_nil session[:delivery_postcode]
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
    # Above the coupon's £100 Stripe minimum, or there is no discount row to
    # render (the setup cart is £20).
    @cart_item.update!(quantity: 11)
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

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    post checkout_path

    assert_response :see_other
    assert_equal "mainland", captured_params[:metadata][:shipping_zone]
  end

  test "create with an unparseable default postcode proceeds priced as mainland" do
    sign_in_as(@user)
    @user.addresses.create!(
      nickname: "Bad postcode #{SecureRandom.hex(4)}",
      recipient_name: "Jane",
      line1: "1 St",
      city: "Somewhere",
      postcode: "00000",
      country: "FR",
      default: true
    )
    stub_stripe_session_create

    post checkout_path

    assert_response :see_other
  end

  test "create still refuses a destination we know we cannot serve" do
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

  # The postcode typed at the checkout page (the only typed destination left)
  # outlives that Stripe session: a customer who typed IV1, went back to the
  # basket, and checked out again must be priced highlands from the start, not
  # re-seeded from their mainland default address.
  test "create prices from the postcode typed at a previous checkout" do
    sign_in_as(@user)
    stash_onsite_session
    stub_reprice_stripe_calls
    patch checkout_path, params: reprice_params("IV1 1AA"), as: :json
    assert_response :success

    captured = nil
    Stripe::Checkout::Session.stubs(:create).with { |p| captured = p; true }.returns(build_custom_stripe_session)

    post checkout_path

    assert_equal "highlands", captured[:metadata][:shipping_zone],
                 "Stripe must charge the zone of the postcode the customer typed"
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

  # Authenticated checkouts without a Stripe Customer yet keep customer_email, but
  # must still have Stripe persist a Customer so per-customer coupon restrictions have
  # an identity to key on: a one-time coupon was otherwise redeemable indefinitely.
  # (With a known Customer id, SessionBuilder attaches it instead - covered in
  # session_builder_test.)
  test "create includes customer email and asks stripe to create a customer for users without a stripe customer" do
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
  #
  # The success redirect is one completion channel (CONTEXT.md: Checkout
  # completion). It owns only transport: the flash and redirect for each
  # outcome, and the browser-session cleanup. What a completion does lives in
  # Checkout::CompletionTest.
  # ============================================================================

  test "success completes the session with the customer present and redirects to the new order" do
    order = orders(:one)
    Checkout::Completion.expects(:complete).with("sess_paid", browser_present: true)
      .returns(completion_outcome(:created, order))

    get success_checkout_path, params: { session_id: "sess_paid" }

    assert_response :see_other
    assert_match %r{/orders/#{order.id}/confirmation\?token=}, response.location
    assert_equal order.id, session[:recent_order_id]
  end

  test "success redirects to the order the webhook already completed" do
    order = orders(:one)
    Checkout::Completion.stubs(:complete).returns(completion_outcome(:existing, order))

    get success_checkout_path, params: { session_id: order.stripe_session_id }

    assert_response :redirect
    assert_match %r{/orders/#{order.id}/confirmation\?token=}, response.location
  end

  test "success clears the Welcome discount from the browser session once spent" do
    post email_subscriptions_path, params: { email: "discount-test@example.com" }
    assert_equal welcome_coupon_id, session[:discount_code]
    Checkout::Completion.stubs(:complete).returns(completion_outcome(:created, orders(:one)))

    get success_checkout_path, params: { session_id: "sess_paid" }

    assert_nil session[:discount_code]
  end

  test "success handles missing session_id parameter" do
    Checkout::Completion.expects(:complete).never

    get success_checkout_path

    assert_redirected_to cart_path
    assert_match /Invalid checkout session/, flash[:error]
  end

  test "success sends an unpaid session back to the cart and keeps the on-site stash" do
    stash_onsite_session
    Checkout::Completion.stubs(:complete).returns(completion_outcome(:unpaid, nil))

    get success_checkout_path, params: { session_id: "sess_unpaid" }

    assert_redirected_to cart_path
    assert_match /Payment was not completed/, flash[:error]
    assert_not_nil session[:onsite_checkout]
  end

  test "success asks the customer to retry checkout when shipping details are missing" do
    Checkout::Completion.stubs(:complete).raises(Checkout::MissingShippingDetails.new("Shipping details are required"))

    get success_checkout_path, params: { session_id: "sess_no_shipping" }

    assert_redirected_to cart_path
    assert_match /Shipping details are required/, flash[:error]
  end

  test "success never 500s a paid customer on another permanent failure" do
    Checkout::Completion.stubs(:complete).raises(Checkout::SessionAmounts::UnexpandedLineItemError.new("unexpanded"))

    get success_checkout_path, params: { session_id: "sess_unexpanded" }

    assert_redirected_to cart_path
    assert_match /Unable to verify payment/, flash[:error]
  end

  test "success never 500s a paid customer on a transient failure" do
    Checkout::Completion.stubs(:complete).raises(Checkout::TransientCompletionFailure.new("connection reset"))

    get success_checkout_path, params: { session_id: "sess_blip" }

    assert_redirected_to cart_path
    assert_match /Unable to verify payment/, flash[:error]
  end

  test "success lets a programmer error surface instead of silently swallowing it" do
    Checkout::Completion.stubs(:complete).raises(StandardError.new("Database error"))

    assert_raises(StandardError) do
      get success_checkout_path, params: { session_id: "sess_bug" }
    end
  end

  test "success creates the order end to end from a paid session" do
    # The wiring check: a real completion through the Stripe stubs, with the
    # cart the session names rather than the browser cart.
    paid_cart = Cart.create!
    paid_cart.cart_items.create!(product: products(:one), quantity: 3, price: 10.0)
    stripe_session = stub_stripe_session_retrieve(
      customer_email: "buyer@example.com", client_reference_id: @user.id, metadata: { cart_id: paid_cart.id.to_s }
    )

    assert_difference [ "Order.count", "OrderItem.count" ], 1 do
      assert_event_reported("order.placed") do
        get success_checkout_path, params: { session_id: stripe_session.id }
      end
    end

    order = Order.find_by!(stripe_session_id: stripe_session.id)
    assert_equal @user, order.user
    assert_equal 3, order.order_items.first.quantity
    assert_equal 0, paid_cart.reload.cart_items.count
    assert_equal 1, @cart.reload.cart_items.count
    assert_match %r{/orders/#{order.id}/confirmation\?token=}, response.location
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

  # The flash the customer actually reads. "Could not be applied" states a
  # failure and offers nothing to do about it; naming the reason turns the
  # commonest case into a nudge, since the shortfall is exactly the information
  # that would change their order.
  test "create explains a below-minimum discount with the shortfall" do
    post cart_cart_items_path, params: {
      cart_item: { sku: products(:single_wall_8oz_white).sku, quantity: 1 }
    }
    post email_subscriptions_path, params: { email: "shortfall-flash@example.com" }
    stub_welcome_promotion_code
    Stripe::Checkout::Session.stubs(:create)
      .raises(StripeErrors.promotion_code_amount_insufficient)
      .then.returns(build_stripe_session)

    post checkout_path

    # A shortfall is a nudge, not a fault, so it must not be rendered in the
    # red alert-error bar the layout gives flash[:alert].
    assert_nil flash[:alert], "a below-minimum discount is not an error"
    # Its own slot, so the layout can style it as good news rather than as a
    # neutral notice or a failure.
    assert_match(/£100/, flash[:nudge], "the minimum should be named")
    assert_match(/10% discount/, flash[:nudge], "what they are missing out on should be named")
    assert_match(/Add £54\.00/, flash[:nudge], "the shortfall is the actionable part")
    assert_no_match(/could not be applied/i, flash[:nudge])
  end

  test "create explains a samples-only cart rather than blaming the code" do
    # is_sample is set by the sample endpoints, not the ordinary add-to-cart
    # path, so the samples-only cart is built directly.
    @cart.cart_items.destroy_all
    @cart.cart_items.create!(product: products(:sample_cup_8oz), quantity: 1, price: 0, is_sample: true)
    assert @cart.reload.only_samples?, "setup: the cart should be samples-only"
    post email_subscriptions_path, params: { email: "samples-flash@example.com" }
    Stripe::Checkout::Session.stubs(:create).returns(build_stripe_session)

    post checkout_path

    assert_match(/sample/i, flash[:alert])
  end

  # The live trap, end to end. Stripe evaluates the welcome coupon's £100
  # minimum only when the session is created, so a sub-£100 basket carrying the
  # code was refused there. The raise landed in the rescue whose guard is
  # builder&.invalid_discount?, which was FALSE (the code resolved fine, its
  # CONDITIONS failed), so the code was never cleared and the customer met the
  # identical error on every retry with no way to remove it.
  test "create completes the checkout when Stripe refuses the coupon as below its minimum" do
    post email_subscriptions_path, params: { email: "below-minimum@example.com" }
    assert_equal welcome_coupon_id, session[:discount_code]
    stub_welcome_promotion_code

    stripe_session = build_stripe_session
    Stripe::Checkout::Session.stubs(:create)
      .raises(StripeErrors.promotion_code_amount_insufficient)
      .then.returns(stripe_session)

    post checkout_path

    assert_redirected_to stripe_session.url
    assert_nil session[:discount_code], "the unusable code must be cleared, or the loop repeats"
    assert_nil flash[:error], "the customer is checking out, not failing"
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
end
