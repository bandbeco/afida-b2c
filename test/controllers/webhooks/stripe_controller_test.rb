# frozen_string_literal: true

require "test_helper"

class Webhooks::StripeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @subscription = subscriptions(:active_monthly)

    # Stripe webhook signature headers
    @webhook_secret = "whsec_test_secret"
    Rails.application.credentials.stubs(:dig).with(:stripe, :webhook_signing_secret).returns(@webhook_secret)

    # Stub Stripe::Webhook.construct_event to return the event hash directly
    # This bypasses real Stripe signature verification while testing controller logic
    Stripe::Webhook.stubs(:construct_event).returns(nil)
  end

  # Helper to set up the stub for a specific event
  def stub_webhook_event(event_hash)
    # Convert to Stripe::Event-like object with hash access
    Stripe::Webhook.stubs(:construct_event).returns(event_hash.deep_stringify_keys)
  end

  # ==========================================================================
  # T038: invoice.paid creates renewal order
  # ==========================================================================

  test "invoice.paid creates renewal order for subscription_cycle billing_reason" do
    event = build_invoice_paid_event(
      billing_reason: "subscription_cycle",
      subscription_id: @subscription.stripe_subscription_id,
      invoice_id: "in_renewal_#{SecureRandom.hex(8)}"
    )
    stub_webhook_event(event)

    assert_difference "Order.count", 1 do
      post webhooks_stripe_path,
           params: event.to_json,
           headers: webhook_headers(event.to_json)
    end

    assert_response :success

    order = Order.last
    assert_equal @subscription, order.subscription
    assert order.stripe_invoice_id.present?
    assert_equal "paid", order.status
  end

  # ==========================================================================
  # T039: invoice.paid is idempotent (no duplicate orders)
  # ==========================================================================

  test "invoice.paid is idempotent - same invoice_id does not create duplicate orders" do
    invoice_id = "in_idempotent_#{SecureRandom.hex(8)}"

    # First webhook call
    event = build_invoice_paid_event(
      billing_reason: "subscription_cycle",
      subscription_id: @subscription.stripe_subscription_id,
      invoice_id: invoice_id
    )
    stub_webhook_event(event)

    post webhooks_stripe_path,
         params: event.to_json,
         headers: webhook_headers(event.to_json)

    assert_response :success
    assert_equal 1, Order.where(stripe_invoice_id: invoice_id).count

    # Second webhook call with same invoice_id (Stripe retry)
    assert_no_difference "Order.count" do
      post webhooks_stripe_path,
           params: event.to_json,
           headers: webhook_headers(event.to_json)
    end

    assert_response :success
    assert_equal 1, Order.where(stripe_invoice_id: invoice_id).count
  end

  # ==========================================================================
  # T040: invoice.paid skips first invoice (subscription_create)
  # ==========================================================================

  test "invoice.paid skips first invoice with subscription_create billing_reason" do
    event = build_invoice_paid_event(
      billing_reason: "subscription_create",
      subscription_id: @subscription.stripe_subscription_id,
      invoice_id: "in_first_#{SecureRandom.hex(8)}"
    )
    stub_webhook_event(event)

    assert_no_difference "Order.count" do
      post webhooks_stripe_path,
           params: event.to_json,
           headers: webhook_headers(event.to_json)
    end

    assert_response :success
  end

  # ==========================================================================
  # T041: invoice.paid sends email notification
  # ==========================================================================

  test "invoice.paid sends email notification for renewal" do
    event = build_invoice_paid_event(
      billing_reason: "subscription_cycle",
      subscription_id: @subscription.stripe_subscription_id,
      invoice_id: "in_email_#{SecureRandom.hex(8)}"
    )
    stub_webhook_event(event)

    assert_enqueued_emails 1 do
      post webhooks_stripe_path,
           params: event.to_json,
           headers: webhook_headers(event.to_json)
    end

    assert_response :success
  end

  # ==========================================================================
  # Additional tests
  # ==========================================================================

  test "returns 200 for unhandled event types" do
    event = {
      id: "evt_test_#{SecureRandom.hex(8)}",
      type: "customer.created",
      data: {
        object: { id: "cus_test" }
      }
    }
    stub_webhook_event(event)

    post webhooks_stripe_path,
         params: event.to_json,
         headers: webhook_headers(event.to_json)

    assert_response :success
  end

  test "returns 400 for invalid signature" do
    # Stub construct_event to raise SignatureVerificationError
    Stripe::Webhook.stubs(:construct_event).raises(
      Stripe::SignatureVerificationError.new("Invalid signature", "sig_header")
    )

    payload = { type: "invoice.paid" }

    post webhooks_stripe_path,
         params: payload.to_json,
         headers: { "Content-Type" => "application/json", "Stripe-Signature" => "invalid_signature" }

    assert_response :bad_request
  end

  # ==========================================================================
  # T053: customer.subscription.updated syncs status
  # ==========================================================================

  test "customer.subscription.updated syncs status from active to paused" do
    @subscription.update!(status: "active")

    event = build_subscription_updated_event(
      subscription_id: @subscription.stripe_subscription_id,
      status: "active",
      pause_collection: { behavior: "void" }
    )
    stub_webhook_event(event)

    post webhooks_stripe_path,
         params: event.to_json,
         headers: webhook_headers(event.to_json)

    assert_response :success
    @subscription.reload
    assert_equal "paused", @subscription.status
  end

  test "customer.subscription.updated syncs status from paused to active" do
    @subscription.update!(status: "paused")

    event = build_subscription_updated_event(
      subscription_id: @subscription.stripe_subscription_id,
      status: "active",
      pause_collection: nil
    )
    stub_webhook_event(event)

    post webhooks_stripe_path,
         params: event.to_json,
         headers: webhook_headers(event.to_json)

    assert_response :success
    @subscription.reload
    assert_equal "active", @subscription.status
  end

  # ==========================================================================
  # T054: customer.subscription.updated syncs billing period dates
  # ==========================================================================

  test "customer.subscription.updated syncs billing period dates" do
    new_period_start = 3.days.from_now.to_i
    new_period_end = 33.days.from_now.to_i

    event = build_subscription_updated_event(
      subscription_id: @subscription.stripe_subscription_id,
      status: "active",
      current_period_start: new_period_start,
      current_period_end: new_period_end
    )
    stub_webhook_event(event)

    post webhooks_stripe_path,
         params: event.to_json,
         headers: webhook_headers(event.to_json)

    assert_response :success
    @subscription.reload
    assert_equal Time.at(new_period_start).utc.to_date, @subscription.current_period_start.to_date
    assert_equal Time.at(new_period_end).utc.to_date, @subscription.current_period_end.to_date
  end

  # ==========================================================================
  # T055: customer.subscription.deleted marks as cancelled
  # ==========================================================================

  test "customer.subscription.deleted marks subscription as cancelled" do
    @subscription.update!(status: "active")

    event = build_subscription_deleted_event(
      subscription_id: @subscription.stripe_subscription_id
    )
    stub_webhook_event(event)

    post webhooks_stripe_path,
         params: event.to_json,
         headers: webhook_headers(event.to_json)

    assert_response :success
    @subscription.reload
    assert_equal "cancelled", @subscription.status
    assert @subscription.cancelled_at.present?
  end

  # ==========================================================================
  # T056: invoice.payment_failed logs warning
  # ==========================================================================

  test "invoice.payment_failed logs warning and returns success" do
    event = build_invoice_payment_failed_event(
      subscription_id: @subscription.stripe_subscription_id,
      invoice_id: "in_failed_#{SecureRandom.hex(8)}"
    )
    stub_webhook_event(event)

    # Test that it returns success and logs (we can't easily assert logs)
    post webhooks_stripe_path,
         params: event.to_json,
         headers: webhook_headers(event.to_json)

    assert_response :success
  end

  # ==========================================================================
  # T043b: IP allowlisting security
  # ==========================================================================

  test "rejects webhook from non-Stripe IP in production" do
    # Simulate production environment
    Rails.env.stubs(:local?).returns(false)

    event = build_invoice_paid_event(
      billing_reason: "subscription_cycle",
      subscription_id: @subscription.stripe_subscription_id,
      invoice_id: "in_ip_test_#{SecureRandom.hex(8)}"
    )
    stub_webhook_event(event)

    # Request from unauthorized IP (default test IP is 127.0.0.1)
    post webhooks_stripe_path,
         params: event.to_json,
         headers: webhook_headers(event.to_json)

    assert_response :forbidden
  end

  test "accepts webhook from allowlisted Stripe IP in production" do
    # Simulate production environment
    Rails.env.stubs(:local?).returns(false)

    event = build_invoice_paid_event(
      billing_reason: "subscription_cycle",
      subscription_id: @subscription.stripe_subscription_id,
      invoice_id: "in_allowed_ip_#{SecureRandom.hex(8)}"
    )
    stub_webhook_event(event)

    # Simulate request from allowed Stripe IP
    allowed_ip = STRIPE_WEBHOOK_IPS.first
    ActionDispatch::Request.any_instance.stubs(:remote_ip).returns(allowed_ip)

    assert_difference "Order.count", 1 do
      post webhooks_stripe_path,
           params: event.to_json,
           headers: webhook_headers(event.to_json)
    end

    assert_response :success
  end

  # ==========================================================================
  # Free shipping threshold tests for renewal orders
  # ==========================================================================

  test "invoice.paid applies free shipping for renewal orders >= £100 subtotal" do
    # Update subscription to have subtotal above threshold (£120 = 12000 pence)
    @subscription.update!(
      items_snapshot: {
        "items" => [
          {
            "product_variant_id" => 1,
            "product_id" => 1,
            "sku" => "SWC-8OZ",
            "name" => "Single Wall Cup 8oz",
            "quantity" => 10,
            "unit_price_minor" => 1200,
            "pac_size" => 500,
            "total_minor" => 12000
          }
        ],
        "subtotal_minor" => 12000,
        "vat_minor" => 2400,
        "total_minor" => 14400,
        "currency" => "gbp"
      }
    )

    event = build_invoice_paid_event(
      billing_reason: "subscription_cycle",
      subscription_id: @subscription.stripe_subscription_id,
      invoice_id: "in_free_shipping_#{SecureRandom.hex(8)}"
    )
    stub_webhook_event(event)

    assert_difference "Order.count", 1 do
      post webhooks_stripe_path,
           params: event.to_json,
           headers: webhook_headers(event.to_json)
    end

    order = Order.last
    assert_equal 0.0, order.shipping_amount, "Shipping should be free for orders >= £100"
  end

  test "invoice.paid applies standard shipping for renewal orders below £100 subtotal" do
    # Subscription fixture has subtotal_minor: 3200 (£32) - below threshold
    # The shipping_snapshot cost is irrelevant - we recalculate based on subtotal
    # Update shipping_snapshot to verify we ignore the stored cost
    shipping = JSON.parse(@subscription.shipping_snapshot)
    shipping["cost_minor"] = 0  # Set to 0 to prove we recalculate, not use stored value
    @subscription.update!(shipping_snapshot: shipping)

    event = build_invoice_paid_event(
      billing_reason: "subscription_cycle",
      subscription_id: @subscription.stripe_subscription_id,
      invoice_id: "in_standard_shipping_#{SecureRandom.hex(8)}"
    )
    stub_webhook_event(event)

    assert_difference "Order.count", 1 do
      post webhooks_stripe_path,
           params: event.to_json,
           headers: webhook_headers(event.to_json)
    end

    order = Order.last
    expected_shipping = Shipping::STANDARD_COST / 100.0
    assert_equal expected_shipping, order.shipping_amount, "Shipping should be £5 for orders below £100"
  end

  test "invoice.paid applies free shipping at exactly £100 threshold" do
    # Update subscription to have subtotal exactly at threshold (£100 = 10000 pence)
    @subscription.update!(
      items_snapshot: {
        "items" => [
          {
            "product_variant_id" => 1,
            "product_id" => 1,
            "sku" => "SWC-8OZ",
            "name" => "Single Wall Cup 8oz",
            "quantity" => 5,
            "unit_price_minor" => 2000,
            "pac_size" => 500,
            "total_minor" => 10000
          }
        ],
        "subtotal_minor" => 10000,
        "vat_minor" => 2000,
        "total_minor" => 12000,
        "currency" => "gbp"
      }
    )

    event = build_invoice_paid_event(
      billing_reason: "subscription_cycle",
      subscription_id: @subscription.stripe_subscription_id,
      invoice_id: "in_threshold_shipping_#{SecureRandom.hex(8)}"
    )
    stub_webhook_event(event)

    assert_difference "Order.count", 1 do
      post webhooks_stripe_path,
           params: event.to_json,
           headers: webhook_headers(event.to_json)
    end

    order = Order.last
    assert_equal 0.0, order.shipping_amount, "Shipping should be free at exactly £100 threshold"
  end

  # ==========================================================================
  # invoice.created adds shipping line item to draft invoices
  # ==========================================================================

  test "invoice.created adds shipping line item for subscription renewal below £100" do
    # Subscription fixture has subtotal_minor: 3200 (£32) - below threshold
    invoice_id = "in_created_#{SecureRandom.hex(8)}"
    customer_id = @subscription.stripe_customer_id

    event = build_invoice_created_event(
      billing_reason: "subscription_cycle",
      subscription_id: @subscription.stripe_subscription_id,
      invoice_id: invoice_id,
      customer_id: customer_id
    )
    stub_webhook_event(event)

    # Expect Stripe::InvoiceItem.create to be called with shipping amount
    Stripe::InvoiceItem.expects(:create).with(
      customer: customer_id,
      invoice: invoice_id,
      amount: Shipping::STANDARD_COST,
      currency: "gbp",
      description: "Standard Shipping"
    ).once

    post webhooks_stripe_path,
         params: event.to_json,
         headers: webhook_headers(event.to_json)

    assert_response :success
  end

  test "invoice.created does NOT add shipping for subscription renewal >= £100" do
    # Update subscription to have subtotal above threshold (£120 = 12000 pence)
    @subscription.update!(
      items_snapshot: {
        "items" => [
          {
            "product_variant_id" => 1,
            "product_id" => 1,
            "sku" => "SWC-8OZ",
            "name" => "Single Wall Cup 8oz",
            "quantity" => 10,
            "unit_price_minor" => 1200,
            "pac_size" => 500,
            "total_minor" => 12000
          }
        ],
        "subtotal_minor" => 12000,
        "vat_minor" => 2400,
        "total_minor" => 14400,
        "currency" => "gbp"
      }
    )

    event = build_invoice_created_event(
      billing_reason: "subscription_cycle",
      subscription_id: @subscription.stripe_subscription_id,
      invoice_id: "in_free_#{SecureRandom.hex(8)}"
    )
    stub_webhook_event(event)

    # Expect Stripe::InvoiceItem.create to NOT be called
    Stripe::InvoiceItem.expects(:create).never

    post webhooks_stripe_path,
         params: event.to_json,
         headers: webhook_headers(event.to_json)

    assert_response :success
  end

  test "invoice.created does NOT add shipping at exactly £100 threshold" do
    # Update subscription to have subtotal exactly at threshold (£100 = 10000 pence)
    @subscription.update!(
      items_snapshot: {
        "items" => [
          {
            "product_variant_id" => 1,
            "product_id" => 1,
            "sku" => "SWC-8OZ",
            "name" => "Single Wall Cup 8oz",
            "quantity" => 5,
            "unit_price_minor" => 2000,
            "pac_size" => 500,
            "total_minor" => 10000
          }
        ],
        "subtotal_minor" => 10000,
        "vat_minor" => 2000,
        "total_minor" => 12000,
        "currency" => "gbp"
      }
    )

    event = build_invoice_created_event(
      billing_reason: "subscription_cycle",
      subscription_id: @subscription.stripe_subscription_id,
      invoice_id: "in_threshold_#{SecureRandom.hex(8)}"
    )
    stub_webhook_event(event)

    # Expect Stripe::InvoiceItem.create to NOT be called (free shipping at threshold)
    Stripe::InvoiceItem.expects(:create).never

    post webhooks_stripe_path,
         params: event.to_json,
         headers: webhook_headers(event.to_json)

    assert_response :success
  end

  test "invoice.created skips first invoice (subscription_create)" do
    event = build_invoice_created_event(
      billing_reason: "subscription_create",
      subscription_id: @subscription.stripe_subscription_id,
      invoice_id: "in_first_#{SecureRandom.hex(8)}"
    )
    stub_webhook_event(event)

    # Expect Stripe::InvoiceItem.create to NOT be called
    Stripe::InvoiceItem.expects(:create).never

    post webhooks_stripe_path,
         params: event.to_json,
         headers: webhook_headers(event.to_json)

    assert_response :success
  end

  test "invoice.created skips non-subscription invoices" do
    event = build_invoice_created_event(
      billing_reason: "manual",
      subscription_id: nil,
      invoice_id: "in_manual_#{SecureRandom.hex(8)}"
    )
    stub_webhook_event(event)

    # Expect Stripe::InvoiceItem.create to NOT be called
    Stripe::InvoiceItem.expects(:create).never

    post webhooks_stripe_path,
         params: event.to_json,
         headers: webhook_headers(event.to_json)

    assert_response :success
  end

  test "invoice.created skips unknown subscriptions" do
    event = build_invoice_created_event(
      billing_reason: "subscription_cycle",
      subscription_id: "sub_unknown_#{SecureRandom.hex(8)}",
      invoice_id: "in_unknown_#{SecureRandom.hex(8)}"
    )
    stub_webhook_event(event)

    # Expect Stripe::InvoiceItem.create to NOT be called
    Stripe::InvoiceItem.expects(:create).never

    post webhooks_stripe_path,
         params: event.to_json,
         headers: webhook_headers(event.to_json)

    assert_response :success
  end

  test "invoice.created handles Stripe API errors gracefully" do
    # Subscription fixture has subtotal_minor: 3200 (£32) - below threshold
    event = build_invoice_created_event(
      billing_reason: "subscription_cycle",
      subscription_id: @subscription.stripe_subscription_id,
      invoice_id: "in_error_#{SecureRandom.hex(8)}"
    )
    stub_webhook_event(event)

    # Simulate Stripe API error
    Stripe::InvoiceItem.stubs(:create).raises(Stripe::InvalidRequestError.new("Invoice is already finalized", param: "invoice"))

    # Stub Sentry to verify error is captured
    Sentry.expects(:capture_exception).once

    post webhooks_stripe_path,
         params: event.to_json,
         headers: webhook_headers(event.to_json)

    # Should still return success (webhook received, error logged)
    assert_response :success
  end

  # ==========================================================================
  # T057: status mapping from Stripe to local enum
  # ==========================================================================

  test "subscription status maps correctly from Stripe statuses" do
    # Test past_due status
    event = build_subscription_updated_event(
      subscription_id: @subscription.stripe_subscription_id,
      status: "past_due"
    )
    stub_webhook_event(event)

    post webhooks_stripe_path,
         params: event.to_json,
         headers: webhook_headers(event.to_json)

    assert_response :success
    @subscription.reload
    assert_equal "past_due", @subscription.status
  end

  private

  def build_invoice_paid_event(billing_reason:, subscription_id:, invoice_id:)
    {
      id: "evt_#{SecureRandom.hex(8)}",
      type: "invoice.paid",
      data: {
        object: {
          id: invoice_id,
          subscription: subscription_id,
          customer: @subscription.stripe_customer_id,
          billing_reason: billing_reason,
          amount_paid: 2600, # £26.00 in pence
          currency: "gbp",
          lines: {
            data: [
              {
                description: "Single Wall 8oz Cup",
                quantity: 1,
                amount: 2600
              }
            ]
          }
        }
      }
    }
  end

  def webhook_headers(payload)
    timestamp = Time.now.to_i
    signature = compute_signature(payload, timestamp)

    {
      "Content-Type" => "application/json",
      "Stripe-Signature" => "t=#{timestamp},v1=#{signature}"
    }
  end

  def compute_signature(payload, timestamp)
    signed_payload = "#{timestamp}.#{payload}"
    OpenSSL::HMAC.hexdigest("SHA256", @webhook_secret, signed_payload)
  end

  def build_subscription_updated_event(subscription_id:, status:, pause_collection: nil, current_period_start: nil, current_period_end: nil)
    {
      id: "evt_#{SecureRandom.hex(8)}",
      type: "customer.subscription.updated",
      data: {
        object: {
          id: subscription_id,
          status: status,
          pause_collection: pause_collection,
          current_period_start: current_period_start || Time.current.to_i,
          current_period_end: current_period_end || 30.days.from_now.to_i
        }
      }
    }
  end

  def build_subscription_deleted_event(subscription_id:)
    {
      id: "evt_#{SecureRandom.hex(8)}",
      type: "customer.subscription.deleted",
      data: {
        object: {
          id: subscription_id,
          status: "canceled"
        }
      }
    }
  end

  def build_invoice_payment_failed_event(subscription_id:, invoice_id:)
    {
      id: "evt_#{SecureRandom.hex(8)}",
      type: "invoice.payment_failed",
      data: {
        object: {
          id: invoice_id,
          subscription: subscription_id,
          attempt_count: 1,
          next_payment_attempt: 3.days.from_now.to_i
        }
      }
    }
  end

  def build_invoice_created_event(billing_reason:, subscription_id:, invoice_id:, customer_id: nil)
    {
      id: "evt_#{SecureRandom.hex(8)}",
      type: "invoice.created",
      data: {
        object: {
          id: invoice_id,
          subscription: subscription_id,
          customer: customer_id || @subscription.stripe_customer_id,
          billing_reason: billing_reason,
          status: "draft",
          currency: "gbp"
        }
      }
    }
  end
end
