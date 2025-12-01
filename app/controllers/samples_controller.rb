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
      .order("products.name", :name)

    # For sample counter and variant cards
    @sample_count = Current.cart&.sample_count || 0
    @cart_variant_ids = Current.cart&.cart_items&.pluck(:product_variant_id) || []

    render partial: "samples/category_variants", locals: {
      category: @category,
      variants: @variants,
      sample_count: @sample_count,
      cart_variant_ids: @cart_variant_ids
    }
  end
end
