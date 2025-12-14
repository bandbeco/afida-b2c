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

    # Detect consolidated products (have material option in variant option_values)
    # Consolidated products use the configurator partial with dynamic filtering
    # Only use configurator if there are actual choices (multiple variants with different options)
    has_material = @product.active_variants.any? { |v| v.option_values["material"].present? }

    if has_material && @product.active_variants.count > 1
      # Build configurator options directly from variant data (not ProductOption tables)
      # Order: material first, then colour (quality-first flow)
      @configurator_options = {}

      # Collect unique values for each option type
      materials = @product.active_variants.map { |v| v.option_values["material"] }.compact.uniq
      colours = @product.active_variants.map { |v| v.option_values["colour"] }.compact.uniq

      # Only include options that have multiple values (real choices)
      @configurator_options["material"] = materials if materials.count > 1
      @configurator_options["colour"] = colours if colours.count > 1

      # Only use consolidated template if there are actual options to choose from
      @is_consolidated = @configurator_options.any?

      # For consolidated products, we don't pre-select anything
      @has_url_selection = false if @is_consolidated
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
