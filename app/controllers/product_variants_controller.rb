# Controller for individual product variant pages
# Each variant (SKU) has its own dedicated page for SEO and direct purchasing
#
# Routes:
#   GET /products/:slug => show
#
# The :slug param matches the variant's slug (e.g., "8oz-white-single-wall-cups")
# This is different from ProductsController which handles consolidated product pages
#
class ProductVariantsController < ApplicationController
  allow_unauthenticated_access

  def show
    @variant = ProductVariant.active.includes(:product).find_by!(slug: params[:slug])
    @product = @variant.product
    @category = @product.category

    # Related variants from the same product (for "See also" section)
    @related_variants = @variant.sibling_variants(limit: 4)
                                .includes(product_photo_attachment: :blob)
  rescue ActiveRecord::RecordNotFound
    render file: Rails.root.join("public", "404.html"), status: :not_found, layout: false
  end
end
