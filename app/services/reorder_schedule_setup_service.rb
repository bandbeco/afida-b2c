# frozen_string_literal: true

class ReorderScheduleSetupService
  Result = Struct.new(:success?, :error, :session, :schedule, keyword_init: true)

  def initialize(user:)
    @user = user
  end

  # Creates a Stripe Checkout Session in setup mode to collect payment method
  def create_stripe_session(order:, success_url:, cancel_url:, frequency: nil)
    customer = ensure_stripe_customer

    session = Stripe::Checkout::Session.create(
      mode: "setup",
      customer: customer.id,
      payment_method_types: [ "card" ],
      success_url: success_url,
      cancel_url: cancel_url,
      metadata: {
        order_id: order.id.to_s,
        user_id: @user.id.to_s,
        frequency: frequency
      }
    )

    Result.new(success?: true, session: session)
  rescue Stripe::StripeError => e
    Result.new(success?: false, error: e.message)
  end

  # Completes setup after Stripe redirect, creating the schedule and items
  def complete_setup(session_id:, frequency:)
    session = Stripe::Checkout::Session.retrieve({
      id: session_id,
      expand: [ "setup_intent.payment_method" ]
    })
    payment_method = session.setup_intent.payment_method
    order_id = session.metadata["order_id"]
    order = Order.find(order_id)

    schedule = create_schedule(
      frequency: frequency,
      payment_method: payment_method,
      order: order
    )

    Result.new(success?: true, schedule: schedule)
  rescue Stripe::StripeError => e
    Result.new(success?: false, error: e.message)
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success?: false, error: e.message)
  end

  private

  def ensure_stripe_customer
    if @user.stripe_customer_id.present?
      Stripe::Customer.retrieve(@user.stripe_customer_id)
    else
      customer = Stripe::Customer.create(
        email: @user.email_address,
        metadata: { user_id: @user.id }
      )
      @user.update!(stripe_customer_id: customer.id)
      customer
    end
  end

  def create_schedule(frequency:, payment_method:, order:)
    ReorderSchedule.transaction do
      schedule = @user.reorder_schedules.create!(
        frequency: frequency,
        next_scheduled_date: calculate_next_date(frequency),
        stripe_payment_method_id: payment_method.id,
        card_brand: payment_method.card&.brand,
        card_last4: payment_method.card&.last4,
        status: :active
      )

      order.order_items.each do |item|
        schedule.reorder_schedule_items.create!(
          product_variant: item.product_variant,
          quantity: item.quantity,
          price: item.price
        )
      end

      schedule
    end
  end

  def calculate_next_date(frequency)
    case frequency.to_s
    when "every_week" then Date.current + 1.week
    when "every_two_weeks" then Date.current + 2.weeks
    when "every_month" then Date.current + 1.month
    when "every_3_months" then Date.current + 3.months
    else
      Date.current + 1.month # default
    end
  end
end
