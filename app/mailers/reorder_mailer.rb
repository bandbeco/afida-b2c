# frozen_string_literal: true

class ReorderMailer < ApplicationMailer
  default from: "orders@afida.com"

  # Sends reminder email when a pending order is created
  # Called 3 days before scheduled delivery
  def order_ready(pending_order)
    @pending_order = pending_order
    @schedule = pending_order.reorder_schedule
    @user = @schedule.user

    @confirm_url = confirm_pending_order_url(
      @pending_order,
      token: @pending_order.confirmation_token
    )

    @edit_url = edit_pending_order_url(
      @pending_order,
      token: @pending_order.edit_token
    )

    mail(
      to: @user.email_address,
      subject: "Your reorder is ready - confirm by #{@pending_order.scheduled_for.strftime('%B %d')}"
    )
  end

  # Sends notification when a pending order expires (wasn't confirmed in time)
  def order_expired(pending_order)
    @pending_order = pending_order
    @schedule = pending_order.reorder_schedule
    @user = @schedule.user
    @next_date = @schedule.next_scheduled_date

    mail(
      to: @user.email_address,
      subject: "Your scheduled order has expired"
    )
  end

  # Sends notification when payment fails during order confirmation
  def payment_failed(pending_order, error_message)
    @pending_order = pending_order
    @schedule = pending_order.reorder_schedule
    @user = @schedule.user
    @error_message = error_message

    @retry_url = edit_pending_order_url(
      @pending_order,
      token: @pending_order.edit_token
    )

    mail(
      to: @user.email_address,
      subject: "Payment failed for your scheduled order"
    )
  end
end
