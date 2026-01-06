require "test_helper"

class ReorderMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:one)
    @product_variant = product_variants(:one)

    @schedule = ReorderSchedule.create!(
      user: @user,
      frequency: :every_month,
      status: :active,
      next_scheduled_date: Date.current,
      stripe_payment_method_id: "pm_test_456"
    )

    @pending_order = PendingOrder.create!(
      reorder_schedule: @schedule,
      scheduled_for: 3.days.from_now.to_date,
      items_snapshot: {
        "items" => [
          {
            "product_variant_id" => @product_variant.id,
            "product_name" => "Single Wall Hot Cup",
            "variant_name" => "Pack of 500",
            "quantity" => 2,
            "price" => "16.00",
            "available" => true
          }
        ],
        "subtotal" => "32.00",
        "vat" => "6.40",
        "shipping" => "0.00",
        "total" => "38.40",
        "unavailable_items" => []
      }
    )
  end

  # ==========================================================================
  # order_ready Email
  # ==========================================================================

  test "order_ready sends to user email" do
    email = ReorderMailer.order_ready(@pending_order)

    assert_equal [ @user.email_address ], email.to
  end

  test "order_ready has appropriate subject" do
    email = ReorderMailer.order_ready(@pending_order)

    assert email.subject.present?
    assert_match(/order|reorder|ready/i, email.subject)
  end

  test "order_ready includes scheduled delivery date" do
    email = ReorderMailer.order_ready(@pending_order)

    # Email uses human-readable format "January 09, 2026" (zero-padded day)
    expected_date = @pending_order.scheduled_for.strftime("%B %d, %Y")
    assert_match expected_date, email.body.encoded
  end

  test "order_ready includes order items" do
    email = ReorderMailer.order_ready(@pending_order)

    assert_match "Single Wall Hot Cup", email.body.encoded
    assert_match "Pack of 500", email.body.encoded
  end

  test "order_ready includes quantities" do
    email = ReorderMailer.order_ready(@pending_order)

    # Should show quantity of 2
    assert_match(/2/, email.body.encoded)
  end

  test "order_ready includes prices" do
    email = ReorderMailer.order_ready(@pending_order)

    assert_match "16.00", email.body.encoded
  end

  test "order_ready includes total" do
    email = ReorderMailer.order_ready(@pending_order)

    assert_match "38.40", email.body.encoded
  end

  test "order_ready includes confirm button/link" do
    email = ReorderMailer.order_ready(@pending_order)

    # Should have confirm URL with token
    assert_match(/confirm/i, email.body.encoded)
    assert_match(/token/, email.body.encoded)
  end

  test "order_ready includes edit button/link" do
    email = ReorderMailer.order_ready(@pending_order)

    # Should have edit URL with token
    assert_match(/edit/i, email.body.encoded)
  end

  test "order_ready review link contains valid token" do
    email = ReorderMailer.order_ready(@pending_order)

    # Extract the review URL from the email body (show action, not confirm action)
    # The email links to the review page where user can see details before confirming
    review_url_match = email.body.encoded.match(/pending-orders\/\d+\?token=([^"&\s]+)/)
    assert review_url_match, "Review URL not found in email"

    token = CGI.unescape(review_url_match[1])
    # Verify token is a valid SGID that resolves to the pending order
    resolved = GlobalID::Locator.locate_signed(token, for: "pending_order_confirm")
    assert_equal @pending_order, resolved
  end

  # ==========================================================================
  # order_ready with Unavailable Items
  # ==========================================================================

  test "order_ready shows warning when items unavailable" do
    @pending_order.update!(
      items_snapshot: {
        "items" => [],
        "subtotal" => "0.00",
        "vat" => "0.00",
        "total" => "0.00",
        "unavailable_items" => [
          {
            "product_variant_id" => 999,
            "product_name" => "Discontinued Cup",
            "variant_name" => "Large",
            "reason" => "Product no longer available"
          }
        ]
      }
    )

    email = ReorderMailer.order_ready(@pending_order)

    assert_match(/unavailable|no longer available/i, email.body.encoded)
    assert_match "Discontinued Cup", email.body.encoded
  end

  # ==========================================================================
  # Email Delivery
  # ==========================================================================

  test "order_ready can be delivered" do
    assert_emails 1 do
      ReorderMailer.order_ready(@pending_order).deliver_now
    end
  end

  test "order_ready has both html and text parts" do
    email = ReorderMailer.order_ready(@pending_order)

    assert email.multipart? || email.content_type.include?("text/html")
  end

  # ==========================================================================
  # order_expired Email (for Phase 8)
  # ==========================================================================

  test "order_expired sends to user email" do
    email = ReorderMailer.order_expired(@pending_order)

    assert_equal [ @user.email_address ], email.to
  end

  test "order_expired has appropriate subject" do
    email = ReorderMailer.order_expired(@pending_order)

    assert email.subject.present?
    assert_match(/expired|missed/i, email.subject)
  end

  test "order_expired explains next steps" do
    email = ReorderMailer.order_expired(@pending_order)

    # Should mention that the schedule continues
    assert_match(/next|continue|schedule/i, email.body.encoded)
  end

  # ==========================================================================
  # payment_failed Email (for Phase 8)
  # ==========================================================================

  test "payment_failed sends to user email" do
    email = ReorderMailer.payment_failed(@pending_order, "Your card was declined")

    assert_equal [ @user.email_address ], email.to
  end

  test "payment_failed has appropriate subject" do
    email = ReorderMailer.payment_failed(@pending_order, "Your card was declined")

    assert email.subject.present?
    assert_match(/payment|failed|declined/i, email.subject)
  end

  test "payment_failed includes error reason" do
    email = ReorderMailer.payment_failed(@pending_order, "Your card was declined")

    assert_match(/declined/i, email.body.encoded)
  end

  test "payment_failed includes retry instructions" do
    email = ReorderMailer.payment_failed(@pending_order, "Your card was declined")

    # Should explain how to retry or update payment method
    assert_match(/update|retry|payment method/i, email.body.encoded)
  end
end
