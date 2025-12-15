# frozen_string_literal: true

# Mailer for subscription-related notifications
#
# Emails:
#   - order_placed: Sent when a renewal order is created via webhook
#
class SubscriptionMailer < ApplicationMailer
  # T048: Sends notification when a subscription order is placed
  #
  # @param order [Order] The order that was created
  #
  def order_placed(order)
    @order = order
    @subscription = order.subscription
    @user = order.user

    mail(
      to: @user.email_address,
      subject: "Your subscription order has been placed"
    )
  end
end
