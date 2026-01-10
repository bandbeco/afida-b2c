class CategoriesController < ApplicationController
  allow_unauthenticated_access

  def show
    @category = Category.find_by!(slug: params[:id])

    # Load variants for products in this category
    @variants = ProductVariant.active
                              .joins(:product)
                              .where(products: { category_id: @category.id, active: true })
                              .includes(product: :category, product_photo_attachment: :blob)
                              .order(position: :asc, id: :asc)

    # Redirect to variant page if only one variant in category
    if @variants.count == 1
      redirect_to product_variant_path(@variants.first.slug, request.query_parameters), status: :moved_permanently
    end
  end
end
