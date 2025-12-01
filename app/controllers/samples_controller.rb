# Controller for samples browsing page
#
# Visitors can browse available sample variants organized by category.
# Categories expand inline via Turbo Frame to show sample-eligible variants.
#
class SamplesController < ApplicationController
  allow_unauthenticated_access

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
      .includes(product: { product_photo_attachment: :blob })
      .order(Arel.sql("products.name, (NULLIF(REGEXP_REPLACE(product_variants.name, '[^0-9].*', '', 'g'), ''))::integer NULLS LAST, product_variants.name"))

    # For sample counter and variant cards
    @sample_count = Current.cart&.sample_count || 0
    # Only include sample cart items (price = 0), not regular items
    @cart_variant_ids = Current.cart&.cart_items&.where(price: 0)&.pluck(:product_variant_id) || []

    render partial: "samples/category_variants", locals: {
      category: @category,
      variants: @variants,
      sample_count: @sample_count,
      cart_variant_ids: @cart_variant_ids
    }
  end
end
