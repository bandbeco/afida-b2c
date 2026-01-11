# Controller for samples browsing page
#
# Visitors can browse available sample products organized by category.
# Categories expand inline via Turbo Frame to show sample-eligible products.
#
class SamplesController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 30, within: 1.minute, only: [ :index, :category ]

  # GET /samples
  # Main samples browsing page showing categories with sample-eligible products
  def index
    @categories = Category
      .joins(:products)
      .where(products: { sample_eligible: true, active: true })
      .distinct
      .order(:position)

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
end
