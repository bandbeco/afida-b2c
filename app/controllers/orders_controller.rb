class OrdersController < ApplicationController
  before_action :require_authentication

  before_action :set_order, only: [ :show ]

  def show
  end

  def index
    @orders = Current.user.orders.recent.includes(:order_items, :products)
  end

  private

  def set_order
    @order = Current.user.orders.includes(order_items: :product_variant).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to orders_path, alert: "Order not found"
  end
end
