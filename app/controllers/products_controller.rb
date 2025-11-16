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
    base_product = Product.find_by!(slug: params[:slug])

    if base_product.customizable_template?
      # For branded products, only need category, image, and branded_product_prices
      @product = Product.includes(:category, :branded_product_prices)
                       .with_attached_product_photo
                       .find_by!(slug: params[:slug])
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
                       .find_by!(slug: params[:slug])
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
      # Eager load option values to prevent N+1 queries
      all_options = @product.options.includes(:values).order(:position)
      @product_options = all_options.select do |option|
        unique_values = @product.active_variants.map { |v| v.option_values[option.name] }.compact.uniq
        unique_values.count > 1
      end

      # Build lookup hash for O(1) label access in views (prevents N+1 queries)
      @option_labels = {}
      @product_options.each do |option|
        @option_labels[option.name] ||= {}
        option.values.each do |ov|
          @option_labels[option.name][ov.value] = ov.label.presence || ov.value
        end
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

  def quick_add
    @product = Product.find_by!(slug: params[:slug])

    # Only allow quick add for standard products
    unless @product.product_type == "standard"
      redirect_to product_path(@product), alert: "Product not available for quick add"
      return
    end

    # Load active variants for the modal
    @variants = @product.active_variants.by_position

    # Load product options (same logic as show action)
    # Exclude options where all variants have identical values (not a real choice)
    all_options = @product.options.includes(:values).order(:position)
    @product_options = all_options.select do |option|
      unique_values = @product.active_variants.map { |v| v.option_values[option.name] }.compact.uniq
      unique_values.count > 1
    end

    # Build lookup hash for option labels
    @option_labels = {}
    @product_options.each do |option|
      @option_labels[option.name] ||= {}
      option.values.each do |ov|
        @option_labels[option.name][ov.value] = ov.label.presence || ov.value
      end
    end

    # Build variants JSON for client-side variant matching
    @variants_json = @variants.map do |v|
      {
        sku: v.sku,
        price: v.price.to_f,
        pac_size: v.pac_size || 1,
        name: v.name,
        option_values: v.option_values
      }
    end

    render layout: false  # Turbo Frame content only
  end
end
