module BrandedProducts
  class InstanceCreatorService
    Result = Struct.new(:success, :product, :error, keyword_init: true) do
      def success?
        success
      end
    end

    def initialize(order_item)
      @order_item = order_item
      @order = order_item.order
    end

    def create_instance_product(name:, sku:, initial_stock:, reorder_price:)
      return error_result("Order item must have configuration") unless @order_item.configured?

      # Reload order to ensure we have fresh data
      @order.reload
      return error_result("Order must belong to an organization") unless @order.organization_id.present?

      validate_params!(name, sku, initial_stock, reorder_price)

      ActiveRecord::Base.transaction do
        product = create_product(name, sku, initial_stock, reorder_price)
        copy_design_to_product(product)
        update_order_status

        Result.new(success: true, product: product)
      end
    rescue ActiveRecord::RecordInvalid => e
      error_result(e.message)
    rescue StandardError => e
      error_result("Failed to create product: #{e.message}")
    end

    private

    def create_product(name, sku, initial_stock, reorder_price)
      Product.create!(
        name: name,
        sku: sku,
        price: reorder_price,
        stock_quantity: initial_stock,
        product_type: "customized_instance",
        organization: @order.organization,
        parent_product: @order_item.product,
        category: @order_item.product.category,
        active: true,
        description_short: "Custom branded product for #{@order.organization.name}"
      )
    end

    def copy_design_to_product(product)
      return unless @order_item.design.attached?

      product.product_photo.attach(@order_item.design.blob)
    end

    def update_order_status
      @order.update!(branded_order_status: "instance_created")
    end

    def validate_params!(name, sku, initial_stock, reorder_price)
      errors = []
      errors << "Name is required" if name.blank?
      errors << "SKU is required" if sku.blank?
      errors << "Initial stock must be positive" if initial_stock.to_i <= 0
      errors << "Reorder price must be positive" if reorder_price.to_f <= 0

      raise ArgumentError, errors.join(", ") if errors.any?
    end

    def error_result(message)
      Result.new(success: false, error: message)
    end
  end
end
