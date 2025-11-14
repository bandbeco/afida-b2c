class Admin::BrandedOrdersController < Admin::ApplicationController
  allow_unauthenticated_access
  skip_before_action :set_current_cart
  layout "admin"

    def index
      # TODO: Filter to only orders with configured products once configuration column exists
      @orders = Order.all.order(created_at: :desc)
    end

    def show
      @order = Order.find(params[:id])
      # TODO: Filter to configured items once configuration column exists
      @configured_items = @order.order_items
    end

    def update_status
      @order = Order.find(params[:id])
      @order.update!(branded_order_status: params[:status])

      redirect_to admin_branded_order_path(@order),
                  notice: "Order status updated to #{params[:status]}"
    end

    def create_instance_product
      @order = Order.find(params[:id])
      @order_item = @order.order_items.find(params[:order_item_id])

      service = BrandedProducts::InstanceCreatorService.new(@order_item)
      result = service.create_instance_product(
        name: params[:product_name],
        sku: params[:sku],
        initial_stock: params[:initial_stock],
        reorder_price: params[:reorder_price]
      )

      if result.success?
        redirect_to admin_branded_order_path(@order),
                    notice: "Customer product created successfully"
      else
        redirect_to admin_branded_order_path(@order),
                    alert: "Failed to create product: #{result.error}"
      end
    end
end
