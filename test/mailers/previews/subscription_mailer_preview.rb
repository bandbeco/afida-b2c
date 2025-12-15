# frozen_string_literal: true

class SubscriptionMailerPreview < ActionMailer::Preview
  # Preview: http://localhost:3000/rails/mailers/subscription_mailer/order_placed
  def order_placed
    # Find an order that belongs to a subscription
    order = Order.joins(:subscription).last || Order.last
    SubscriptionMailer.order_placed(order)
  end
end
