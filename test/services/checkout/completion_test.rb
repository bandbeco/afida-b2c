require "test_helper"

# Checkout completion (CONTEXT.md): a paid Checkout Session becomes exactly one
# Order with its invariant side effects, whichever completion channel arrives
# first. These tests are the single home for "what happens when an order
# completes"; the two controller tests cover only their transport.
class Checkout::CompletionTest < ActiveSupport::TestCase
  include StripeTestHelper
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  setup do
    @cart = Cart.create!
    @cart_item = @cart.cart_items.create!(product: products(:one), quantity: 2, price: 10.00)
    Sentry.stubs(:capture_exception)
  end

  test "the webhook channel emits order.placed so Klaviyo sees every order" do
    stub_paid_session

    assert_event_reported("order.placed", payload: { source: "checkout" }) do
      Checkout::Completion.complete(@session.id, browser_present: false)
    end
  end


  test "creates the order once and fires the effects, then finds it on the next arrival" do
    stub_paid_session
    Ga4MeasurementProtocolService.stubs(:track_purchase)

    first = nil
    assert_difference [ "Order.count", "OrderItem.count" ], 1 do
      first = Checkout::Completion.complete(@session.id, browser_present: false)
    end
    assert first.created?
    assert_equal @session.id, first.order.stripe_session_id
    assert_equal "paid", first.order.status
    assert_equal 0, @cart.reload.cart_items.count

    second = nil
    assert_no_difference "Order.count" do
      assert_no_event_reported("order.placed") do
        second = Checkout::Completion.complete(@session.id, browser_present: true)
      end
    end
    assert second.existing?
    assert_equal first.order, second.order
  end

  test "retrieves the session with the expands the money and address reads need" do
    Stripe::Checkout::Session.expects(:retrieve)
      .with(id: "sess_x", expand: Checkout::Completion::EXPAND)
      .returns(build_stripe_session(id: "sess_x", metadata: { cart_id: @cart.id.to_s }))

    Checkout::Completion.complete("sess_x", browser_present: true)
  end

  test "an order that already exists is found without asking Stripe" do
    Stripe::Checkout::Session.expects(:retrieve).never

    outcome = Checkout::Completion.complete(orders(:one).stripe_session_id, browser_present: false)

    assert outcome.existing?
    assert_equal orders(:one), outcome.order
  end

  test "an unpaid session yields no order and no effects" do
    stub_paid_session(payment_status: "unpaid")

    outcome = nil
    assert_no_difference "Order.count" do
      assert_no_event_reported("checkout.completed") do
        outcome = Checkout::Completion.complete(@session.id, browser_present: true)
      end
    end
    assert outcome.unpaid?
    assert_nil outcome.order
    assert_equal 1, @cart.reload.cart_items.count
  end

  test "a setup-mode session (reorder card capture) is not a checkout and yields nothing" do
    # Stripe completes setup sessions as no_payment_required; they carry no
    # shipping details and must never be reported as failed completions.
    stub_paid_session(mode: "setup", payment_status: "no_payment_required")
    Sentry.expects(:capture_exception).never

    outcome = nil
    assert_no_difference "Order.count" do
      outcome = Checkout::Completion.complete(@session.id, browser_present: false)
    end
    assert outcome.unpaid?
  end

  test "a Stripe request error that is not resource_missing is still transient" do
    # Stripe uses InvalidRequestError for some retryable conditions too
    # (lock_timeout); only a missing resource can never succeed on retry.
    Stripe::Checkout::Session.stubs(:retrieve)
      .raises(Stripe::InvalidRequestError.new("lock timeout", nil, code: "lock_timeout"))
    Sentry.expects(:capture_exception).once

    assert_raises(Checkout::TransientCompletionFailure) do
      Checkout::Completion.complete("sess_locked", browser_present: false)
    end
  end

  test "a session Stripe cannot find is a permanent failure" do
    Stripe::Checkout::Session.stubs(:retrieve)
      .raises(Stripe::InvalidRequestError.new("No such session", "id", code: "resource_missing"))
    Sentry.expects(:capture_exception).once

    error = assert_raises(Checkout::PermanentCompletionFailure) do
      Checkout::Completion.complete("sess_missing", browser_present: true)
    end
    assert_kind_of Stripe::InvalidRequestError, error.cause
  end

  test "a zero-total session completes as no_payment_required" do
    stub_paid_session(payment_status: "no_payment_required", amount_total: 0)

    assert Checkout::Completion.complete(@session.id, browser_present: true).created?
  end

  test "a missing cart still records the paid order and reports it for reconciliation" do
    stub_paid_session(metadata: { cart_id: "999999" })
    Sentry.expects(:capture_message).once

    outcome = nil
    assert_difference "Order.count", 1 do
      outcome = Checkout::Completion.complete(@session.id, browser_present: true)
    end
    assert outcome.created?
    assert_empty outcome.order.order_items
  end

  test "an itemless order skips the customer confirmation email but sends ops confirmation" do
    stub_paid_session(metadata: { cart_id: "999999" })
    Sentry.stubs(:capture_message)

    # Only one email should be enqueued (ops confirmation, not customer)
    assert_enqueued_emails 1 do
      Checkout::Completion.complete(@session.id, browser_present: true)
    end
  end

  test "cart/session mismatch is detected and reported when item added after pricing" do
    # Cart has 2 items but session only paid for 1
    stub_paid_session(
      amount_subtotal: 1000, # £10.00 in pence
      line_items_data: [ stripe_product_line_item(amount_subtotal: 1000, name: "Product", id: "li_1") ]
    )
    Sentry.expects(:capture_message).with(
      "Cart/session mismatch: items added after pricing",
      has_entries(level: :error, extra: has_entry(:session_item_count, 1))
    ).once

    Checkout::Completion.complete(@session.id, browser_present: true)
  end

  test "cart/session match does not report when cart matches session" do
    # Cart has 1 item priced at £10, session has matching line item
    @cart.cart_items.destroy_all
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    stub_paid_session(
      amount_subtotal: 1000, # £10.00 in pence
      line_items_data: [
        stripe_product_line_item(amount_subtotal: 1000, name: "Product", id: "li_1")
      ]
    )
    Sentry.expects(:capture_message).with(includes("mismatch"), anything).never

    Checkout::Completion.complete(@session.id, browser_present: true)
  end

  test "cart/session match with discount does not false-positive" do
    # Stripe line-item amount_subtotal is pre-discount (amount_total =
    # amount_subtotal + tax - discount). A discount must not look like the cart
    # and the session disagree.
    @cart.cart_items.destroy_all
    @cart.cart_items.create!(product: products(:one), quantity: 2, price: 10.00)

    stub_paid_session(
      amount_subtotal: 2000,
      amount_discount: 200,
      line_items_data: [
        stripe_product_line_item(
          amount_subtotal: 2000,
          quantity: 2,
          name: "Product",
          id: "li_1"
        )
      ]
    )
    Sentry.expects(:capture_message).with(includes("mismatch"), anything).never

    Checkout::Completion.complete(@session.id, browser_present: true)
  end

  test "cart/session match with tax does not false-positive" do
    # Tax is added on top of the subtotal and doesn't affect line item amount_subtotal
    @cart.cart_items.destroy_all
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    stub_paid_session(
      amount_subtotal: 1000,
      amount_total: 1200, # includes £2 tax
      line_items_data: [
        stripe_product_line_item(amount_subtotal: 1000, name: "Product", id: "li_1")
      ]
    )
    Sentry.expects(:capture_message).with(includes("mismatch"), anything).never

    Checkout::Completion.complete(@session.id, browser_present: true)
  end

  test "cart/session match with custom price does not false-positive" do
    # A cart item with a custom/promotional price that matches what Stripe charged
    @cart.cart_items.destroy_all
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 8.50)

    stub_paid_session(
      amount_subtotal: 850,
      line_items_data: [
        stripe_product_line_item(amount_subtotal: 850, name: "Product", id: "li_1")
      ]
    )
    Sentry.expects(:capture_message).with(includes("mismatch"), anything).never

    Checkout::Completion.complete(@session.id, browser_present: true)
  end

  test "mismatch detector failing with nil amount_subtotal still creates the order" do
    # A line item with nil amount_subtotal would raise TypeError in sum(&:amount_subtotal).
    # The detect-only check must not block order creation. Built without the
    # line-item helper, which multiplies amount_subtotal and cannot represent nil.
    line = stub(
      id: "li_nil",
      description: "Product",
      quantity: 1,
      amount_subtotal: nil,
      amount_tax: 0,
      amount_total: 0,
      price: stub(product: Stripe::StripeObject.construct_from("metadata" => {}))
    )
    stub_paid_session(line_items_data: [ line ])
    Sentry.expects(:capture_exception).with(
      instance_of(TypeError),
      has_entries(extra: { stripe_session_id: @session.id })
    )

    outcome = nil
    assert_difference "Order.count", 1 do
      outcome = Checkout::Completion.complete(@session.id, browser_present: true)
    end
    assert outcome.created?
  end

  test "mismatch detector failing with Stripe error still creates the order" do
    # SessionLineItems.list can raise Stripe::StripeError during pagination.
    # The detect-only check must not block order creation. The money read pages
    # the same list, so the first call fails the diagnostic and the next succeeds.
    stub_paid_session(line_items_has_more: true)
    Checkout::SessionLineItems.stubs(:list)
      .raises(Stripe::APIConnectionError.new("timeout"))
      .then.returns([])
    Sentry.expects(:capture_exception).with(
      instance_of(Stripe::APIConnectionError),
      has_entries(extra: { stripe_session_id: @session.id })
    )

    outcome = nil
    assert_difference "Order.count", 1 do
      outcome = Checkout::Completion.complete(@session.id, browser_present: true)
    end
    assert outcome.created?
  end

  test "claims the Welcome discount from Stripe metadata, never from a browser session" do
    stub_paid_session(metadata: { discount_code: "WELCOME10" })

    assert_event_reported("email_signup.discount_claimed", payload: { discount_code: "WELCOME10" }) do
      assert_event_reported("order.placed", payload: { has_discount: true }) do
        Checkout::Completion.complete(@session.id, browser_present: false)
      end
    end
  end

  test "fires the GA4 fallback only on the webhook channel" do
    stub_paid_session
    Ga4MeasurementProtocolService.expects(:track_purchase).never
    Checkout::Completion.complete(@session.id, browser_present: true)

    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)
    stub_paid_session(id: "sess_webhook")
    Ga4MeasurementProtocolService.expects(:track_purchase).once
    Checkout::Completion.complete(@session.id, browser_present: false)
  end

  test "attributes the Datafast conversion to the visitor recorded on the session" do
    stub_paid_session(metadata: { datafast_visitor_id: "visitor-9" })

    events = capture_events { Checkout::Completion.complete(@session.id, browser_present: false) }
    completed = events.find { |e| e[:name] == "checkout.completed" }
    assert_equal "visitor-9", completed[:context][:datafast_visitor_id]
  end

  test "a session with no shipping details is a permanent failure, reported once" do
    stub_paid_session(shipping_address: { line1: nil, line2: nil, city: nil, postal_code: nil, country: nil })
    Sentry.expects(:capture_exception).once

    assert_no_difference "Order.count" do
      assert_raises(Checkout::MissingShippingDetails) do
        Checkout::Completion.complete(@session.id, browser_present: true)
      end
    end
  end

  test "a dropped expand is a permanent failure, reported once" do
    stub_paid_session
    Checkout::SessionAmounts.stubs(:from).raises(Checkout::SessionAmounts::UnexpandedLineItemError.new("unexpanded"))
    Sentry.expects(:capture_exception).once

    error = assert_raises(Checkout::PermanentCompletionFailure) do
      Checkout::Completion.complete(@session.id, browser_present: false)
    end
    assert_kind_of Checkout::SessionAmounts::UnexpandedLineItemError, error
  end

  test "a Stripe error while retrieving is a transient failure" do
    Stripe::Checkout::Session.stubs(:retrieve).raises(Stripe::APIConnectionError.new("timeout"))
    Sentry.expects(:capture_exception).once

    error = assert_raises(Checkout::TransientCompletionFailure) do
      Checkout::Completion.complete("sess_gone", browser_present: true)
    end
    assert_kind_of Stripe::StripeError, error.cause
  end

  test "an item rollback that leaves no order is a transient failure" do
    stub_paid_session
    OrderItem.any_instance.stubs(:save!).raises(ActiveRecord::RecordInvalid.new(OrderItem.new))
    Sentry.expects(:capture_exception).once

    assert_no_difference "Order.count" do
      assert_raises(Checkout::TransientCompletionFailure) do
        Checkout::Completion.complete(@session.id, browser_present: false)
      end
    end
    assert_equal 1, @cart.reload.cart_items.count
  end

  test "losing the create race to the other channel finds that order instead" do
    stub_paid_session
    winner = Order.create!(
      email: "buyer@example.com", stripe_session_id: @session.id, status: "paid",
      subtotal_amount: 10, vat_amount: 2, shipping_amount: 0, total_amount: 12,
      shipping_name: "Test Customer", shipping_address_line1: "1 Street", shipping_city: "London",
      shipping_postal_code: "SW1A 1AA", shipping_country: "GB"
    )
    # The other channel commits between our find_by and our create!.
    Order.stubs(:find_by).with(stripe_session_id: @session.id).returns(nil).then.returns(winner)

    outcome = nil
    assert_no_event_reported("order.placed") do
      outcome = Checkout::Completion.complete(@session.id, browser_present: true)
    end
    assert outcome.existing?
    assert_equal winner, outcome.order
  end

  test "a programmer error propagates untouched" do
    stub_paid_session
    Order.any_instance.stubs(:save!).raises(StandardError.new("Database error"))

    assert_raises(StandardError) do
      Checkout::Completion.complete(@session.id, browser_present: true)
    end
  end

  test "redirect and webhook both completing the same session only creates one order" do
    # This models the common case where both channels fire: the webhook wins
    # the create race, commits the order, then the redirect finds it.
    stub_paid_session
    Ga4MeasurementProtocolService.stubs(:track_purchase)

    # Webhook channel completes first (browser_present: false)
    webhook_outcome = nil
    assert_difference [ "Order.count", "OrderItem.count" ], 1 do
      webhook_outcome = Checkout::Completion.complete(@session.id, browser_present: false)
    end
    assert webhook_outcome.created?
    webhook_order = webhook_outcome.order

    # Redirect channel arrives second (browser_present: true)
    redirect_outcome = nil
    assert_no_difference "Order.count" do
      assert_no_event_reported("order.placed") do
        redirect_outcome = Checkout::Completion.complete(@session.id, browser_present: true)
      end
    end
    assert redirect_outcome.existing?
    assert_equal webhook_order, redirect_outcome.order
  end

  test "deterministic validation failure is permanent, not endlessly retried" do
    stub_paid_session

    # Stub OrderCreator to raise an Order validation error (deterministic)
    order_with_error = Order.new(stripe_session_id: @session.id)
    order_with_error.errors.add(:email, "is invalid")
    validation_error = ActiveRecord::RecordInvalid.new(order_with_error)

    Checkout::OrderCreator.any_instance.stubs(:create).raises(validation_error)

    # Should report to Sentry at error level and raise PermanentCompletionFailure (2xx to Stripe)
    Sentry.expects(:capture_exception).once

    error = assert_raises(Checkout::PermanentCompletionFailure) do
      Checkout::Completion.complete(@session.id, browser_present: false)
    end

    assert_match(/invalid/i, error.message)
  end

  test "Order RecordInvalid reports exactly once to Sentry with validation errors and session data" do
    stub_paid_session

    # An Order validation error (deterministic failure)
    order_with_error = Order.new(stripe_session_id: @session.id, email: "")
    order_with_error.errors.add(:email, "can't be blank")
    order_with_error.errors.add(:shipping_name, "is too short")
    validation_error = ActiveRecord::RecordInvalid.new(order_with_error)

    Checkout::OrderCreator.any_instance.stubs(:create).raises(validation_error)

    # Should capture exactly once with validation errors and session context
    Sentry.expects(:capture_exception).once.with(
      validation_error,
      has_entries(
        level: :error,
        extra: has_entries(
          stripe_session_id: @session.id,
          validation_errors: { email: [ "can't be blank" ], shipping_name: [ "is too short" ] },
          customer_email: "buyer@example.com",
          session_amount_total: anything,
          session_line_items_summary: anything
        )
      )
    )

    assert_raises(Checkout::PermanentCompletionFailure) do
      Checkout::Completion.complete(@session.id, browser_present: false)
    end
  end

  test "MissingShippingDetails reports exactly once to Sentry with session data" do
    stub_paid_session(shipping_address: { line1: nil, line2: nil, city: nil, postal_code: nil, country: nil })

    Sentry.expects(:capture_exception).once.with(
      instance_of(Checkout::MissingShippingDetails),
      has_entries(
        level: :error,
        extra: has_entries(
          stripe_session_id: @session.id,
          customer_email: "buyer@example.com",
          session_amount_total: anything,
          session_line_items_summary: anything
        )
      )
    )

    assert_no_difference "Order.count" do
      assert_raises(Checkout::MissingShippingDetails) do
        Checkout::Completion.complete(@session.id, browser_present: true)
      end
    end
  end

  private

  # A paid, expanded session whose metadata names @cart, as SessionBuilder
  # writes it. Stubs the retrieve so the module's own fetch returns it.
  def stub_paid_session(overrides = {})
    metadata = { cart_id: @cart.id.to_s }.merge(overrides.delete(:metadata) || {})
    @session = stub_stripe_session_retrieve({ customer_email: "buyer@example.com", metadata: metadata }.merge(overrides))
  end
end
