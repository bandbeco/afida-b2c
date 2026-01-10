class PagesController < ApplicationController
  allow_unauthenticated_access

  def home
    @featured_products = Product.featured
                                .with_attached_product_photo
                                .includes(:variants)
                                .limit(8)
    @featured_straw_product = Product.standard.find_by(slug: "bio-fibre-straws")
    @categories = Category.with_attached_image.all
    @client_logos = client_logos
  end

  def shop
    # Shop page now displays individual variants instead of products
    @variants = ProductVariant
      .active
      .joins(:product)
      .where(products: { active: true, product_type: :standard })
      .includes(product: :category, product_photo_attachment: :blob)

    # Get categories with their variant counts
    category_variant_counts = @variants
      .joins(product: :category)
      .group("categories.id")
      .count

    @categories = Category.where(id: category_variant_counts.keys).order(:position)
    @category_variant_counts = category_variant_counts

    # Search and category filter are mutually exclusive
    # If searching, ignore category filter
    if params[:q].present?
      @variants = @variants.search_extended(params[:q])
    else
      @variants = @variants.in_categories(params[:categories])
    end

    # Apply option filters (size, colour, material)
    @variants = @variants.with_size(params[:size]) if params[:size].present?
    @variants = @variants.with_colour(params[:colour]) if params[:colour].present?
    @variants = @variants.with_material(params[:material]) if params[:material].present?

    # Apply sorting
    @variants = @variants.sorted(params[:sort])

    # Get available filter values from remaining variants for dynamic filter options
    @available_filters = build_available_filters(@variants)

    @pagy, @variants = pagy(@variants)
  end

  def branding
    @client_logos = client_logos
  end

  def samples
  end

  def about
    @client_logos = client_logos
  end

  def contact
  end

  def terms_conditions
  end

  def privacy_policy
  end

  def cookies_policy
  end

  def accessibility_statement
  end

  def pattern_demo
  end

  def sentry_test
    # This action is only available in development mode (see routes.rb)
    error_type = params[:type] || "exception"

    case error_type
    when "exception"
      begin
        raise StandardError, "Test exception from browser - #{Time.current}"
      rescue StandardError => e
        Sentry.capture_exception(e)
        render plain: "✓ Exception sent to Sentry!\n\nException: #{e.message}\n\nCheck your Sentry dashboard."
      end
    when "message"
      Sentry.capture_message("Test message from browser - #{Time.current}", level: :info)
      render plain: "✓ Message sent to Sentry!\n\nCheck your Sentry dashboard."
    when "error"
      # This will trigger a 500 error that Sentry will automatically catch
      raise StandardError, "Unhandled error test - #{Time.current}"
    else
      render plain: <<~TEXT
        Sentry Test Page (Development Only)

        Available test types:
        - /sentry-test (default exception test)
        - /sentry-test?type=exception (captured exception)
        - /sentry-test?type=message (info message)
        - /sentry-test?type=error (unhandled error - triggers 500)

        Check your Sentry dashboard after triggering a test.
      TEXT
    end
  end

  private

  # Build hash of available filter values from current variant set
  # Returns: { size: ["8oz", "12oz"], colour: ["White", "Black"], material: ["Paper", "Bamboo"] }
  def build_available_filters(variants)
    # Get all option values for the current variant set
    variant_ids = variants.reorder(nil).pluck(:id)

    return {} if variant_ids.empty?

    # Query option values through the join table
    option_data = VariantOptionValue
      .joins(product_option_value: :product_option)
      .where(product_variant_id: variant_ids)
      .select("product_options.name as option_name, product_option_values.value, product_option_values.label")
      .distinct

    # Group by option name
    filters = {}
    option_data.each do |record|
      option_name = record.option_name
      filters[option_name] ||= []
      filters[option_name] << { value: record.value, label: record.label.presence || record.value }
    end

    # Sort values within each filter and remove duplicates
    filters.transform_values! do |values|
      values.uniq { |v| v[:value] }.sort_by { |v| v[:label].downcase }
    end

    filters
  end

  def client_logos
    [
      "ballie-ballerson.webp",
      "edwardian-hotels.svg",
      "hawksmoor.webp",
      "hurlingham.webp",
      "la-gelateria.webp",
      "mandarin-oriental.svg",
      "marriott.svg",
      "pixel-bar.webp",
      "royal-lancaster.svg",
      "the-grove.webp",
      "vincenzos.svg"
    ]
  end
end
