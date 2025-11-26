class Admin::OrdersController < Admin::ApplicationController
  layout "admin"

  def index
    @orders = Order.all
  end

  def show
    @order = Order.includes(order_items: :product_variant).find(params[:id])
  end
end
