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
    advance_schedule(pending_order.reorder_schedule)
    send_expiration_email(pending_order)
  end

  # Without this an active schedule whose reminder went unanswered would stay
  # overdue forever and never generate another pending order
  def advance_schedule(schedule)
    schedule.advance_past_due! if schedule.active?
  end

  def send_expiration_email(pending_order)
    ReorderMailer.order_expired(pending_order).deliver_later
  end
end
