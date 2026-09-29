require "test_helper"

# Checkout completion (CONTEXT.md): a paid Checkout Session becomes exactly one
# Order with its invariant side effects, whichever completion channel arrives
# first. These tests are the single home for "what happens when an order
# completes"; the two controller tests cover only their transport.
class Checkout::CompletionTest < ActiveSupport::TestCase
  include StripeTestHelper

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

  private

  # A paid, expanded session whose metadata names @cart, as SessionBuilder
  # writes it. Stubs the retrieve so the module's own fetch returns it.
  def stub_paid_session(overrides = {})
    metadata = { cart_id: @cart.id.to_s }.merge(overrides.delete(:metadata) || {})
    @session = stub_stripe_session_retrieve({ customer_email: "buyer@example.com", metadata: metadata }.merge(overrides))
  end
end
