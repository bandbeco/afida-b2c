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

    # Check if this is an explicit selection (URL params present)
    @has_url_selection = params[:size].present? || params[:colour].present? || params[:variant_id].present?

    # Detect products that need the configurator (sparse matrix of options)
    # Use configurator when: multiple variants with 2+ option types AND not all combinations exist
    # This prevents impossible state selection (e.g., selecting size + colour that has no variant)
    if @product.active_variants.count > 1
      # Collect all option keys used across variants
      all_option_keys = @product.active_variants.flat_map { |v| v.option_values.keys }.uniq

      # Build configurator options from variant data (order matters for UX)
      # Priority: material > size > colour (quality/size first, then aesthetic)
      option_priority = %w[material size colour]
      ordered_keys = (option_priority & all_option_keys) + (all_option_keys - option_priority)

      @configurator_options = {}
      ordered_keys.each do |key|
        values = @product.active_variants.map { |v| v.option_values[key] }.compact.uniq
        @configurator_options[key] = values if values.count > 1
      end

      # Check if this is a sparse matrix (not all combinations exist)
      # If product has 2+ option types with multiple values, check if it's sparse
      if @configurator_options.size >= 2
        total_combinations = @configurator_options.values.map(&:count).reduce(1, :*)
        actual_variants = @product.active_variants.count
        is_sparse = actual_variants < total_combinations

        # Use configurator for sparse matrices OR products with material option (consolidated products)
        has_material = @configurator_options.key?("material")
        @is_consolidated = is_sparse || has_material

        # For consolidated products, we don't pre-select anything
        @has_url_selection = false if @is_consolidated
      end
    end

    unless @is_consolidated
      # Standard product flow - use ProductOption tables
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
