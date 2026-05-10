class PagesController < ApplicationController
  allow_unauthenticated_access

  def home
    @featured_products = Product.featured
                                .with_attached_product_photo
                                .limit(8)
    @featured_straw_product = Product.catalog_products.find_by(slug: "bio-fibre-straws")
    @categories = Category.browsable.subcategories.includes(:parent).with_attached_image
    @collections = Collection.regular.featured.where.not(slug: Collection::VEGWARE_SLUG).by_position.with_attached_image
    @client_logos = client_logos
  end

  # Legacy category filter slugs that survived in external backlinks and
  # Google's index after the category restructure. Redirect single-slug filter
  # URLs to the new category pages to recover link equity.
  LEGACY_CATEGORY_FILTER_REDIRECTS = {
    "cups-and-lids" => "/categories/cups-and-drinks",
    "ice-cream-cups" => "/categories/cups-and-drinks/ice-cream-cups",
    "napkins" => "/categories/tableware/napkins",
    "pizza-boxes" => "/categories/hot-food/pizza-boxes"
  }.freeze

  def shop
    if (target = legacy_category_filter_target)
      redirect_to target, status: :moved_permanently
      return
    end

    @products = Product
      .active
      .standard
      .includes(:category, product_photo_attachment: :blob, lifestyle_photo_attachment: :blob)

    # Build hierarchical category structure for sidebar
    # Count products per subcategory
    subcategory_counts = @products.group(:category_id).count

    # Load all subcategories and parent categories (show even if empty)
    all_subcategories = Category.subcategories.order(:position)
    @parent_categories = Category.browsable.top_level
      .where(id: Category.subcategories.select(:parent_id))
      .order(:position)

    @subcategories_by_parent = all_subcategories.group_by(&:parent_id)
    @subcategory_product_counts = subcategory_counts

    @parent_product_counts = @parent_categories.each_with_object({}) do |parent, hash|
      children = @subcategories_by_parent[parent.id] || []
      hash[parent.id] = children.sum { |c| subcategory_counts[c.id] || 0 }
    end

    # Search and category filter are mutually exclusive
    # If searching, ignore category filter
    if params[:q].present?
      @products = @products.search_extended(params[:q])
    else
      @products = @products.in_categories(params[:categories])
    end

    # Apply attribute filters (direct column filters)
    @products = @products.with_brand(params[:brand])
    @products = @products.with_colour(params[:colour])
    @products = @products.with_material(params[:material])

    # Apply sorting
    @products = @products.sorted(params[:sort])

    # Build available filter values from current product set
    @available_filters = build_available_filters(@products)

    # Available brands for sidebar (from full active catalogue, not filtered set)
    @available_brands = Product.active.standard
      .where.not(brand: [ nil, "" ])
      .distinct.pluck(:brand).sort

    @products = @products.to_a
  end

  def branding
    @client_logos = client_logos
  end

  def samples
  end

  def vegware
    @collection = Collection.regular.find_by!(slug: Collection::VEGWARE_SLUG)
    @vegware_categories = Category.browsable.top_level
                                  .where(id: @collection.products.joins(:category).select("categories.parent_id"))
                                  .order(:position)

    # Map each category to the product_photo of its first vegware product
    vegware_product_ids = @collection.products.select(:id)
    first_products = Product.where(id: vegware_product_ids)
                            .joins(:category, :product_photo_attachment)
                            .where(categories: { parent_id: @vegware_categories.map(&:id) })
                            .includes(:category, product_photo_attachment: :blob)
                            .order(:position)
    @category_images = {}
    first_products.each do |product|
      parent_id = product.category.parent_id
      @category_images[parent_id] ||= product.product_photo
    end

    @client_logos = client_logos
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

  # Returns a redirect target path if the incoming request is a single-slug
  # legacy filter URL (e.g. /shop?categories[]=cups-and-lids) AND the slug is
  # no longer a real category. Multi-slug selections are treated as active
  # user filtering and are left alone.
  def legacy_category_filter_target
    slugs = Array(params[:categories]).compact_blank
    return nil unless slugs.size == 1

    slug = slugs.first
    target = LEGACY_CATEGORY_FILTER_REDIRECTS[slug]
    return nil if target.nil?
    return nil if Category.exists?(slug: slug)

    target
  end

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
    helpers.client_logos
  end
end
