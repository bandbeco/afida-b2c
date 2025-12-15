# frozen_string_literal: true

# Controller for subscription checkout flow
#
# Handles creating Stripe Checkout Sessions in subscription mode,
# processing successful checkouts, and handling cancellations.
#
# Routes:
#   POST /subscription_checkouts      -> create
#   GET  /subscription_checkouts/success -> success
#   GET  /subscription_checkouts/cancel  -> cancel
#
class SubscriptionCheckoutsController < ApplicationController
  # T023: Cart must have items
  before_action :require_cart_with_items, only: :create

  # T024: Samples-only carts cannot be subscriptions
  before_action :reject_samples_only_cart, only: :create

  # T025: Create subscription checkout session
  #
  # Creates a Stripe Checkout Session in subscription mode and redirects
  # the user to Stripe to complete payment.
  #
  # POST /subscription_checkouts
  # Params:
  #   frequency - Subscription frequency (every_week, every_two_weeks, every_month, every_3_months)
  #
  def create
    frequency = params[:frequency]

    unless Subscription.frequencies.key?(frequency)
      flash[:alert] = "Invalid subscription frequency"
      redirect_to cart_path and return
    end

    Rails.logger.info("[Subscription] Creating checkout session for user=#{Current.user.id} frequency=#{frequency} cart_items=#{Current.cart.cart_items.count}")

    service = SubscriptionCheckoutService.new(
      cart: Current.cart,
      user: Current.user,
      frequency: frequency
    )

    begin
      session = service.create_checkout_session(
        success_url: success_subscription_checkouts_url,
        cancel_url: cancel_subscription_checkouts_url
      )

      Rails.logger.info("[Subscription] Checkout session created: #{session.id}")
      redirect_to session.url, allow_other_host: true, status: :see_other
    rescue Stripe::StripeError => e
      Rails.logger.error("[Subscription] Stripe error creating checkout: #{e.message}")
      flash[:alert] = "Payment service error. Please try again."
      redirect_to cart_path
    end
  end

  # T026: Handle successful checkout callback
  #
  # Called by Stripe after successful payment. Creates the subscription
  # and first order records.
  #
  # GET /subscription_checkouts/success
  # Params:
  #   session_id - Stripe Checkout Session ID
  #
  def success
    session_id = params[:session_id]

    unless session_id.present?
      Rails.logger.warn("[Subscription] Success callback missing session_id")
      flash[:alert] = "Something went wrong. Please try again."
      redirect_to cart_path and return
    end

    Rails.logger.info("[Subscription] Processing success callback for session=#{session_id}")

    service = SubscriptionCheckoutService.new(
      cart: Current.cart,
      user: Current.user,
      frequency: nil # Retrieved from session metadata
    )

    result = service.complete_checkout(session_id)

    if result.success?
      Rails.logger.info("[Subscription] Subscription created: subscription=#{result.subscription&.id} order=#{result.order&.id}")
      flash[:notice] = "Subscription created! Your first order has been placed."
      redirect_to order_path(result.order)
    else
      Rails.logger.error("[Subscription] Failed to complete checkout: #{result.error_message}")
      flash[:alert] = result.error_message
      redirect_to cart_path
    end
  end

  # T027: Handle cancelled checkout
  #
  # Called by Stripe when user cancels the checkout flow.
  #
  # GET /subscription_checkouts/cancel
  #
  def cancel
    flash[:notice] = "Subscription checkout was cancelled. Your cart is still here."
    redirect_to cart_path
  end

  private

  # T023: Require cart to have items
  def require_cart_with_items
    if Current.cart.blank? || Current.cart.cart_items.empty?
      flash[:alert] = "Your cart is empty"
      redirect_to cart_path
    end
  end

  # T024: Reject carts that only contain samples
  def reject_samples_only_cart
    if Current.cart.only_samples?
      flash[:alert] = "Subscriptions are not available for sample orders"
      redirect_to cart_path
    end
  end
end
