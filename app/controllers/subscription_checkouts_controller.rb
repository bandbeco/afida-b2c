# frozen_string_literal: true

# Controller for subscription checkout flow
#
# Handles creating Stripe Checkout Sessions in subscription mode,
# processing successful checkouts, and handling cancellations.
#
# Mixed carts are supported:
# - Standard products become recurring (billed every delivery)
# - Samples ship free with first order only
# - Branded products are charged once and ship with first order
#
# Routes:
#   POST /subscription_checkouts      -> create
#   GET  /subscription_checkouts/success -> success
#   GET  /subscription_checkouts/cancel  -> cancel
#
class SubscriptionCheckoutsController < ApplicationController
  # Rate limit checkout creation to prevent abuse (5 attempts per minute per user)
  rate_limit to: 5, within: 1.minute, only: :create, with: -> {
    flash[:alert] = "Too many checkout attempts. Please wait a moment and try again."
    redirect_to cart_path
  }

  # Subscriptions require authentication - no guest subscriptions
  before_action :require_authentication

  # Cart must have at least one subscription-eligible item (standard product)
  before_action :require_subscription_eligible_items, only: :create

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

      # Send confirmation email for first subscription order
      OrderMailer.with(order: result.order).confirmation_email.deliver_later

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

  # Require cart to have at least one subscription-eligible item
  #
  # Subscription-eligible items are standard products (not samples, not branded).
  # Mixed carts are allowed - samples and branded items become one-time charges.
  def require_subscription_eligible_items
    if Current.cart.blank? || !Current.cart.subscription_eligible?
      flash[:alert] = "Your cart has no items eligible for subscription"
      redirect_to cart_path
    end
  end
end
