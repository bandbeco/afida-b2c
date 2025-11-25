class BrandedProductsController < ApplicationController
  allow_unauthenticated_access

  def index
    @products = Product.branded
                       .includes(:category, :branded_product_prices)
                       .with_attached_product_photo
  end

  def show
    # Check if this is for modal display
    @in_modal = params[:modal] == "true"

    # Load branded product with appropriate associations
    @product = Product.branded
                     .includes(:category, :branded_product_prices)
                     .with_attached_product_photo
                     .find_by!(slug: params[:slug])

    # Load data for configurator
    service = BrandedProductPricingService.new(@product)
    @available_sizes = service.available_sizes
    @quantity_tiers = service.available_quantities(@available_sizes.first) if @available_sizes.any?

    # Load other branded products for add-ons carousel (not needed in modal)
    unless @in_modal
      @addon_products = Product.branded
                              .where.not(id: @product.id)
                              .includes(:branded_product_prices)
                              .with_attached_product_photo
                              .order(:sort_order)
                              .limit(10)
    end

    # Render modal-specific configurator if needed
    if @in_modal
      render partial: "branded_configurator_modal", locals: { product: @product }
      nil
    end
  end
end
