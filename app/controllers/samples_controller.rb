# Controller for samples browsing page
#
# Visitors can browse available sample products organized by category.
# Categories expand inline via Turbo Frame to show sample-eligible products.
#
class SamplesController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 30, within: 1.minute, only: [ :index, :category, :pack, :add_pack ]

  # GET /samples
  # Main samples browsing page showing categories with sample-eligible products
  def index
    @categories = Category
      .joins(:products)
      .where(products: { sample_eligible: true, active: true, product_type: "standard" })
      .distinct
      .order(:position)

    # Load curated sample packs
    @sample_packs = Collection.sample_packs
                              .by_position
                              .includes(image_attachment: :blob)

    # For sample counter
    @sample_count = Current.cart&.sample_count || 0

    # Get selected sample counts by category with a single grouped query
    @selected_samples_by_category = Current.cart&.cart_items
      &.samples
      &.joins(:product)
      &.group("products.category_id")
      &.count || {}
  end

  # GET /samples/:category_slug
  # Returns products for a category (Turbo Frame response)
  def category
    @category = Category.find_by!(slug: params[:category_slug])

    @products = Product
      .standard
      .sample_eligible
      .where(category: @category, active: true)
      .with_attached_product_photo
      .with_attached_lifestyle_photo
      .includes(
        { product_photo_attachment: :blob },
        { lifestyle_photo_attachment: :blob }
      )
      .naturally_sorted

    # For sample counter and product cards
    @sample_count = Current.cart&.sample_count || 0
    # Use memoized methods to prevent N+1 queries
    @sample_product_ids = Current.cart&.sample_product_ids || []
    @regular_product_ids = Current.cart&.regular_product_ids || []

    render partial: "samples/category_variants", locals: {
      category: @category,
      products: @products,
      sample_count: @sample_count,
      sample_product_ids: @sample_product_ids,
      regular_product_ids: @regular_product_ids
    }
  end

  # GET /samples/pack/:slug
  # Shows a curated sample pack page
  def pack
    @sample_pack = Collection.sample_packs.find_by!(slug: params[:slug])
    @products = @sample_pack.sample_eligible_products
                            .includes(:category, product_photo_attachment: :blob)
                            .order("collection_items.position ASC")

    @sample_count = Current.cart&.sample_count || 0
    @sample_product_ids = Current.cart&.sample_product_ids || []
  end

  # POST /samples/add_pack
  # Adds all sample-eligible products from a pack to cart
  def add_pack
    @sample_pack = Collection.sample_packs.find_by!(slug: params[:slug])
    products = @sample_pack.sample_eligible_products.to_a

    # Use existing cart or the one set by application controller
    cart = Current.cart

    added_count = 0
    skipped_count = 0

    products.each do |product|
      # Skip if already in cart (as sample or regular item)
      next if cart.cart_items.exists?(product: product)

      # Check sample limit
      if cart.at_sample_limit?
        skipped_count += products.length - added_count
        break
      end

      # Add as sample (price = 0, is_sample = true)
      cart.cart_items.create!(product: product, quantity: 1, price: 0, is_sample: true)
      added_count += 1
    end

    if skipped_count > 0
      flash[:notice] = "Added #{added_count} samples. #{skipped_count} items not added due to the #{Cart::SAMPLE_LIMIT}-sample limit."
    elsif added_count > 0
      flash[:notice] = "Added #{added_count} samples to your cart!"
    else
      flash[:notice] = "All items were already in your cart."
    end

    redirect_to cart_path
  end
end
