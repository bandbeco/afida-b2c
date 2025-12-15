# frozen_string_literal: true

# Handles guest-to-account conversion after checkout
#
# This controller allows guests who just completed checkout to create
# an account using just a password (email is taken from the order).
# The order is then linked to the new account.
#
# Prerequisites:
# - session[:recent_order_id] must be set (proves order ownership)
# - Order must not already have a user
# - User must not be logged in
#
class PostCheckoutRegistrationsController < ApplicationController
  include Authentication

  allow_unauthenticated_access only: [ :create ]

  before_action :require_guest
  before_action :require_recent_order
  before_action :require_order_without_user

  def create
    @user = User.new(
      email_address: @order.email,
      password: user_params[:password],
      password_confirmation: user_params[:password_confirmation]
    )

    if @user.save
      # Link order to new user
      @order.update!(user: @user)

      # Log in the new user
      start_new_session_for(@user)

      redirect_to confirmation_order_path(@order, token: @order.signed_access_token),
                  notice: "Account created! You can now view your order history."
    else
      handle_registration_failure
    end
  end

  private

  def user_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def require_guest
    return unless authenticated?

    redirect_to root_path, alert: "You already have an account."
  end

  def require_recent_order
    @order = Order.find_by(id: session[:recent_order_id])

    unless @order
      redirect_to root_path, alert: "No recent order found."
    end
  end

  def require_order_without_user
    return unless @order&.user_id.present?

    redirect_to root_path, alert: "This order already has an account."
  end

  def handle_registration_failure
    # Check if email is already taken
    if User.exists?(email_address: @order.email)
      @user.errors.add(:base, "An account with this email already exists.")
      @email_already_registered = true
    end

    # Set variables needed by confirmation view
    @should_track_ga4 = false # Don't re-fire on error re-render

    render "orders/confirmation", status: :unprocessable_entity
  end
end
