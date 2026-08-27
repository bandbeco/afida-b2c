# frozen_string_literal: true

# Notifies Afida's Telegram group chat that a new order has been placed.
#
# Fire-and-forget: discards any error so a Telegram problem never affects the
# order flow. The notifier itself also swallows its own errors.
class TelegramOrderNotificationJob < ApplicationJob
  queue_as :default
  discard_on StandardError

  def perform(order_id)
    order = Order.includes(:order_items).find_by(id: order_id)
    return unless order

    TelegramNotifier.notify_new_order(order)

    # Margot's research lands in the same group, so it rides the same
    # trigger; the job itself skips returning customers.
    MargotResearchJob.perform_later(order.id)
  end
end
