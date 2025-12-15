# frozen_string_literal: true

require "test_helper"

class SubscriptionMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:one)
    @subscription = subscriptions(:active_monthly)
    @order = orders(:one)
    @order.update!(subscription: @subscription, user: @user)
  end

  test "order_placed email has correct subject" do
    email = SubscriptionMailer.order_placed(@order)

    assert_equal "Your subscription order has been placed", email.subject
  end

  test "order_placed email is sent to user" do
    email = SubscriptionMailer.order_placed(@order)

    assert_equal [ @user.email_address ], email.to
  end

  test "order_placed email includes order details" do
    email = SubscriptionMailer.order_placed(@order)

    assert_match @order.id.to_s, email.body.encoded
    assert_match /subscription/i, email.body.encoded
  end

  test "order_placed email includes delivery frequency" do
    email = SubscriptionMailer.order_placed(@order)

    assert_match /month/i, email.body.encoded
  end

  test "order_placed email is multipart" do
    email = SubscriptionMailer.order_placed(@order)

    assert email.multipart?
    assert email.html_part.present?
    assert email.text_part.present?
  end
end
