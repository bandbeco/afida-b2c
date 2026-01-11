# frozen_string_literal: true

class CreatePendingOrdersJob < ApplicationJob
  queue_as :default

  DAYS_BEFORE_DELIVERY = 3

  # Finds all active schedules due in DAYS_BEFORE_DELIVERY days
  # and creates pending orders for them with current prices
  def perform
    schedules_due.each do |schedule|
      create_pending_order(schedule)
    end
  end

  private

  def schedules_due
    ReorderSchedule
      .active
      .due_in_days(DAYS_BEFORE_DELIVERY)
      .includes(reorder_schedule_items: :product)
  end

  def create_pending_order(schedule)
    snapshot = PendingOrderSnapshotBuilder.new(schedule).build

    pending_order = schedule.pending_orders.create!(
      scheduled_for: schedule.next_scheduled_date,
      items_snapshot: snapshot
    )

    send_reminder_email(pending_order)
  rescue ActiveRecord::RecordNotUnique
    # Already created by another worker - skip silently
    # This handles race conditions when multiple Solid Queue workers
    # process the same schedule concurrently
    Rails.logger.info("Pending order already exists for schedule #{schedule.id}, date #{schedule.next_scheduled_date}")
  end

  def send_reminder_email(pending_order)
    ReorderMailer.order_ready(pending_order).deliver_later
  end
end
