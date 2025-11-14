class ProductsController < ApplicationController
  allow_unauthenticated_access

  def index
    @products = Product.includes(:category, :active_variants)
                       .with_attached_product_photo
                       .all
  end

  def show
    # Check if this is for modal display
    @in_modal = params[:modal] == "true"

    # Load product with appropriate associations based on type
    # We check product_type first to avoid N+1 queries
    base_product = Product.find_by!(slug: params[:id])

    if base_product.customizable_template?
      # For branded products, only need category, image, and branded_product_prices
      @product = Product.includes(:category, :branded_product_prices)
                       .with_attached_product_photo
                       .find_by!(slug: params[:id])
      # Load data for configurator
      service = BrandedProductPricingService.new(@product)
      @available_sizes = service.available_sizes
      @quantity_tiers = service.available_quantities(@available_sizes.first) if @available_sizes.any?

      # Load other branded products for add-ons carousel (not needed in modal)
      unless @in_modal
        @addon_products = Product.where(product_type: "customizable_template")
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
    elsif base_product.standard? || base_product.customized_instance?
      # For standard products, need variants with their images (not product-level photos)
      @product = Product.includes(:category)
                       .find_by!(slug: params[:id])
      # Eager load variant photos for @variants_json mapping (primary_photo needs both)
      @product.active_variants.includes(:product_photo_attachment, :lifestyle_photo_attachment).load
      # Logic for standard products and customized instances (both have variants)
      @selected_variant = if params[:variant_id].present?
        @product.active_variants.find_by(id: params[:variant_id])
      end

      @selected_variant ||= @product.default_variant

      # Redirect if no variants available
      unless @selected_variant
        redirect_to products_path, alert: "This product is currently unavailable."
        return
      end

      # Calculate minimum price for "from" display
      @min_price = @product.active_variants.minimum(:price)

      # Check if this is an explicit selection (URL params present)
      @has_url_selection = params[:size].present? || params[:colour].present? || params[:variant_id].present?

      # Prepare data for option selectors
      # Exclude options where all variants have identical values (not a real choice)
      @product_options = @product.options.order(:position).select do |option|
        unique_values = @product.active_variants.map { |v| v.option_values[option.name] }.compact.uniq
        unique_values.count > 1
      end
      @variants_json = @product.active_variants.map do |v|
        {
          id: v.id,
          sku: v.sku,
          price: v.price.to_f,
          pac_size: v.pac_size || 1,
          option_values: v.option_values,
          image_url: v.primary_photo&.attached? ? url_for(v.primary_photo.variant(resize_to_limit: [ 800, 800 ])) : nil
        }
      end
    end
  end
end
