# Controller for product pages
#
# Product is the main sellable entity. Products can optionally belong to
# a ProductFamily for grouping related products (e.g., different sizes
# of the same cup type). Sibling products in the same family are shown
# in a "See Also" section on the product page.
#
class ProductsController < ApplicationController
  allow_unauthenticated_access

  def index
    @products = Product.active
                       .catalog_products
                       .includes(:category, product_photo_attachment: :blob)
                       .order(position: :asc, id: :asc)
  end

  def show
    # Check if this is for modal display
    @in_modal = params[:modal] == "true"

    @product = Product.active
                      .includes(:category, :product_family, :compatible_lids)
                      .find_by!(slug: params[:slug])

    @category = @product.category

    # Compatible products (e.g., lids for cups)
    @compatible_products = @product.compatible_lids
                                   .active
                                   .includes(product_photo_attachment: :blob)
                                   .limit(4)

    # Related products from the same family (for "See Also" section)
    @related_products = @product.siblings(limit: 4)
                                .includes(product_photo_attachment: :blob)

    # Fallback to same category if no family siblings
    if @related_products.empty?
      @related_products = Product.active
                                 .catalog_products
                                 .where(category: @category)
                                 .where.not(id: @product.id)
                                 .includes(product_photo_attachment: :blob)
                                 .limit(4)
    end
  rescue ActiveRecord::RecordNotFound
    render file: Rails.root.join("public", "404.html"), status: :not_found, layout: false
  end

  def quick_add
    @product = Product.active.catalog_products.find_by!(slug: params[:slug])

    render layout: false  # Turbo Frame content only
  end
end
