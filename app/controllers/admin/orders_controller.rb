class Admin::OrdersController < Admin::ApplicationController
  layout "admin"

  def index
    @orders = filter_by_sample_status(Order.includes(order_items: :product).recent)
  end

  def show
    @order = Order.includes(order_items: :product).find(params[:id])
  end

  private

  def filter_by_sample_status(orders)
    case params[:sample_status]
    when "samples_only"
      orders.with_samples.select(&:sample_request?)
    when "contains_samples"
      orders.with_samples
    when "no_samples"
      orders.where.not(id: Order.with_samples.select(:id))
    else
      orders
    end
  end
end
