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

    # Load standard product with appropriate associations
    # ProductsController only handles standard products; branded products use BrandedProductsController
    @product = Product.standard
                     .includes(:category)
                     .find_by!(slug: params[:slug])
    # Eager load variant photos for @variants_json mapping (primary_photo needs both)
    @product.active_variants.includes(:product_photo_attachment, :lifestyle_photo_attachment).load

    # Select variant based on params
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

    # === UNIFIED VARIANT SELECTOR ===
    # Uses Product#extract_options_from_variants and Product#variants_for_selector
    # for the new unified variant_selector Stimulus controller

    # Extract options with multiple values, sorted by priority (material → type → size → colour)
    @options = @product.extract_options_from_variants

    # Build variants JSON with all fields needed by the selector (including pricing_tiers)
    @variants_json = @product.variants_for_selector

    # Set pac_size for display (used in quantity calculations)
    @pac_size = @selected_variant&.pac_size || @product.active_variants.first&.pac_size || 1

    # Related products from same category (for "You May Also Like" section)
    @related_products = @product.category.products
                                .standard
                                .where.not(id: @product.id)
                                .includes(:active_variants)
                                .with_attached_product_photo
                                .limit(8)

    # Fallback to bestsellers if not enough same-category products
    if @related_products.length < 4
      exclude_ids = [ @product.id ] + @related_products.map(&:id)
      bestsellers = Product.standard
                           .featured
                           .where.not(id: exclude_ids)
                           .includes(:active_variants)
                           .with_attached_product_photo
                           .limit(8 - @related_products.length)
      @related_products = @related_products.to_a + bestsellers.to_a
    end
  end

  def quick_add
    # Quick add only works for standard products
    @product = Product.standard.find_by!(slug: params[:slug])

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
