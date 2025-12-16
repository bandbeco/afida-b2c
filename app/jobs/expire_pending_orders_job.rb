# frozen_string_literal: true

class ExpirePendingOrdersJob < ApplicationJob
  queue_as :default

  # Pending orders expire after this many days
  EXPIRATION_DAYS = 7

  def perform
    expired_pending_orders.find_each do |pending_order|
      expire_pending_order(pending_order)
    end
  end

  private

  def expired_pending_orders
    PendingOrder.pending.where("scheduled_for < ?", EXPIRATION_DAYS.days.ago.to_date)
  end

  def expire_pending_order(pending_order)
    pending_order.expire!
    send_expiration_email(pending_order)
  end

  def send_expiration_email(pending_order)
    ReorderMailer.order_expired(pending_order).deliver_later
  end
end
