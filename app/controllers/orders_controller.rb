class OrdersController < ApplicationController
  # Allow guest access to show (for order confirmation after checkout)
  # Index requires authentication (order history)
  allow_unauthenticated_access only: [ :show ]
  before_action :require_authentication, only: [ :index ]

  # Resume session for show action so we can check if user owns the order
  # (skip_before_action skips resume_session, so Current.user would be nil)
  before_action :resume_session, only: [ :show ]
  before_action :set_order, only: [ :show ]

  def show
  end

  def index
    @orders = Current.user.orders.recent.includes(:order_items, :products)
  end

  private

  def set_order
    @order = find_authorized_order
  rescue ActiveRecord::RecordNotFound
    redirect_to orders_path, alert: "Order not found"
  end

  # Find order with proper authorization:
  # - Authenticated users can view their own orders
  # - Guest orders can be viewed if accessed right after checkout (via session)
  # - Orders can be accessed via secure token in URL (for email links)
  def find_authorized_order
    order = Order.includes(order_items: { product_variant: :product }).find(params[:id])

    # Allow if user owns the order
    if Current.user && order.user_id == Current.user.id
      return order
    end

    # Allow if order was just created in this session (guest checkout)
    # The flash message proves they just completed checkout
    if flash[:notice]&.include?(order.display_number)
      return order
    end

    # Allow access via secure token (for email links)
    if params[:token].present? && secure_token_valid?(order, params[:token])
      return order
    end

    # Otherwise, deny access
    raise ActiveRecord::RecordNotFound
  end

  # Generate a secure token for order access (used in email links)
  def secure_token_valid?(order, token)
    expected_token = Digest::SHA256.hexdigest("#{order.id}-#{order.stripe_session_id}-#{Rails.application.secret_key_base}")
    ActiveSupport::SecurityUtils.secure_compare(token, expected_token)
  end
end
