# Controller for samples browsing page
#
# Visitors can browse available sample variants organized by category.
# Categories expand inline via Turbo Frame to show sample-eligible variants.
#
class SamplesController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 30, within: 1.minute, only: [ :index, :category ]

  # GET /samples
  # Main samples browsing page showing categories with sample-eligible variants
  def index
    @categories = Category
      .joins(products: :variants)
      .where(product_variants: { sample_eligible: true, active: true })
      .where(products: { active: true })
      .distinct
      .order(:position)

    # For sample counter
    @sample_count = Current.cart&.sample_count || 0

    # Get selected sample counts by category with a single grouped query
    @selected_samples_by_category = Current.cart&.cart_items
      &.where(price: 0)
      &.joins(product_variant: :product)
      &.group("products.category_id")
      &.count || {}
  end

  # GET /samples/:category_slug
  # Returns variants for a category (Turbo Frame response)
  def category
    @category = Category.find_by!(slug: params[:category_slug])

    @variants = ProductVariant
      .sample_eligible
      .joins(:product)
      .where(products: { category_id: @category.id, active: true })
      .where(active: true)
      .with_attached_product_photo
      .with_attached_lifestyle_photo
      .includes(product: [
        { product_photo_attachment: :blob },
        { lifestyle_photo_attachment: :blob }
      ])
      .order("products.name")
      .naturally_sorted

    # For sample counter and variant cards
    @sample_count = Current.cart&.sample_count || 0
    # Use memoized methods to prevent N+1 queries
    @sample_variant_ids = Current.cart&.sample_variant_ids || []
    @regular_variant_ids = Current.cart&.regular_variant_ids || []

    render partial: "samples/category_variants", locals: {
      category: @category,
      variants: @variants,
      sample_count: @sample_count,
      sample_variant_ids: @sample_variant_ids,
      regular_variant_ids: @regular_variant_ids
    }
  end
end
