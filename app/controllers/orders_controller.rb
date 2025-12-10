class OrdersController < ApplicationController
  # Allow guest access to show and confirmation (for order confirmation after checkout)
  # Index requires authentication (order history)
  allow_unauthenticated_access only: [ :show, :confirmation ]
  before_action :require_authentication, only: [ :index ]

  # Resume session for show/confirmation so we can check if user owns the order
  before_action :resume_session, only: [ :show, :confirmation ]
  before_action :set_order, only: [ :show, :confirmation ]
  before_action :authorize_order_access!, only: [ :show, :confirmation ]

  def confirmation
    # Atomic GA4 tracking - prevents race condition on concurrent requests
    # Returns true only if THIS request set the timestamp (first time)
    @should_track_ga4 = @order.mark_ga4_tracked!
  end

  def show
  end

  def index
    @orders = Current.user.orders.recent.includes(:order_items, :products)
  end

  private

  def set_order
    @order = Order.includes(order_items: { product_variant: :product }).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Order not found"
  end

  # Single authorization method for both show and confirmation actions
  # Access granted if: user owns order, session owns order, or valid token provided
  def authorize_order_access!
    return if owns_order?
    return if session_owns_order?
    return if valid_token_access?

    redirect_to root_path, alert: "Order not found"
  end

  def owns_order?
    Current.user && @order.user_id == Current.user.id
  end

  # Session proves THIS user just created THIS order (secure)
  # Set in CheckoutsController#success after order creation
  def session_owns_order?
    session[:recent_order_id] == @order.id
  end

  def valid_token_access?
    return false unless params[:token].present?

    # Use Rails signed global ID for verification
    located_order = GlobalID::Locator.locate_signed(params[:token], for: "order_access")
    located_order == @order
  rescue ActiveRecord::RecordNotFound, ActiveSupport::MessageVerifier::InvalidSignature
    false
  end
end
