class BrandedProductsController < ApplicationController
  allow_unauthenticated_access

  # Multi-step size dimensions for products with composite size keys.
  # Each dimension becomes a separate accordion step; selections are
  # joined with spaces to compose the pricing lookup key.
  SIZE_DIMENSIONS = {
    "greaseproof-paper" => [
      { key: "paper_size", label: "Select paper size", options: [ "A4", "A3" ] },
      { key: "paper_type", label: "Select paper type", options: [ "White", "Kraft" ] },
      { key: "print_colours", label: "Select colour", options: [ "1 Colour", "2 Colours" ] }
    ]
  }.freeze

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
    @has_lids = @product.compatible_lids.exists?

    # Multi-dimension size config (e.g., greaseproof paper: paper_size × paper_type × colours)
    @size_dimensions = SIZE_DIMENSIONS[@product.slug]
    if @size_dimensions
      @all_quantity_tiers = @available_sizes.each_with_object({}) do |size, hash|
        hash[size] = service.available_quantities(size)
      end
    end

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
