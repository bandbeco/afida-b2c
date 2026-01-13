class PagesController < ApplicationController
  allow_unauthenticated_access

  def home
    @featured_products = Product.featured
                                .with_attached_product_photo
                                .limit(8)
    @featured_straw_product = Product.catalog_products.find_by(slug: "bio-fibre-straws")
    @categories = Category.browsable.with_attached_image
    @client_logos = client_logos
  end

  def shop
    @products = Product
      .active
      .catalog_products
      .includes(:category, product_photo_attachment: :blob)

    # Get categories with their product counts
    category_product_counts = @products
      .group(:category_id)
      .count

    @categories = Category.browsable.where(id: category_product_counts.keys).order(:position)
    @category_product_counts = category_product_counts

    # Search and category filter are mutually exclusive
    # If searching, ignore category filter
    if params[:q].present?
      @products = @products.search_extended(params[:q])
    else
      @products = @products.in_categories(params[:categories])
    end

    # Apply attribute filters (direct column filters)
    @products = @products.with_colour(params[:colour])
    @products = @products.with_material(params[:material])

    # Apply sorting
    @products = @products.sorted(params[:sort])

    # Build available filter values from current product set
    @available_filters = build_available_filters(@products)

    @products = @products.to_a
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

  def return_policy
  end

  def delivery_returns
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

  # Build hash of available filter values from current product set
  # Queries direct Product columns (colour, material)
  # Returns: { "colour" => ["White", "Black"], "material" => ["Paper", "Bamboo"] }
  def build_available_filters(products)
    product_ids = products.reorder(nil).pluck(:id)
    return {} if product_ids.empty?

    filters = {}

    # Get distinct colour values
    colours = Product.where(id: product_ids).where.not(colour: [ nil, "" ]).distinct.pluck(:colour).sort
    filters["colour"] = colours.map { |c| { value: c, label: c } } if colours.any?

    # Get distinct material values
    materials = Product.where(id: product_ids).where.not(material: [ nil, "" ]).distinct.pluck(:material).sort
    filters["material"] = materials.map { |m| { value: m, label: m } } if materials.any?

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
