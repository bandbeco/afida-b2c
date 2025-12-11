class PagesController < ApplicationController
  allow_unauthenticated_access

  def home
    @featured_products = Product.featured
                                .with_attached_product_photo
                                .includes(:variants)
                                .limit(8)
    @featured_straw_product = Product.standard.find_by(slug: "biodegradable-straws")
    @categories = Category.with_attached_image.all
    @client_logos = client_logos
  end

  def shop
    @products = Product
      .standard
      .includes(:active_variants,
                product_photo_attachment: :blob,
                lifestyle_photo_attachment: :blob)

    @categories = Category.where(id: @products.pluck(:category_id).uniq).order(:position)

    # Search and category filter are mutually exclusive
    # If searching, ignore category filter
    if params[:q].present?
      @products = @products.search(params[:q])
    else
      @products = @products.in_categories(params[:categories])
    end

    # Apply sorting
    @products = @products.sorted(params[:sort])

    @pagy, @products = pagy(@products)
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

  def articles
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
