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

    # Eager load variants with photos and blobs to prevent N+1 queries
    # Store in instance variable to reuse throughout the action
    @variants = @product.active_variants
                        .includes(product_photo_attachment: :blob, lifestyle_photo_attachment: :blob)
                        .to_a

    # Build hash lookup for O(1) variant access in JSON building
    variant_lookup = @variants.index_by(&:id)

    # Select variant based on params
    @selected_variant = if params[:variant_id].present?
      variant_lookup[params[:variant_id].to_i]
    end

    @selected_variant ||= @product.default_variant

    # Redirect if no variants available
    unless @selected_variant
      redirect_to products_path, alert: "This product is currently unavailable."
      return
    end

    # Calculate minimum price for "from" display
    @min_price = @variants.map(&:price).min

    # === UNIFIED VARIANT SELECTOR ===
    # Uses Product#available_options and Product#variants_for_selector
    # for the new unified variant_selector Stimulus controller

    # Extract options with multiple values, sorted by priority (material → type → size → colour)
    @options = @product.available_options

    # Build variants JSON with all fields needed by the selector (including pricing_tiers)
    # Populate image URLs here where URL helpers are available
    # Uses variant_lookup hash for O(1) access instead of O(n) Array#find
    @variants_json = @product.variants_for_selector(@variants).map do |variant_data|
      variant = variant_lookup[variant_data[:id]]
      if variant&.primary_photo&.attached?
        variant_data[:image_url] = url_for(variant.primary_photo)
      end
      variant_data
    end

    # Set pac_size for display (used in quantity calculations)
    @pac_size = @selected_variant&.pac_size || @variants.first&.pac_size || 1

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
      unique_values = @product.active_variants.map { |v| v.option_values_hash[option.name] }.compact.uniq
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
