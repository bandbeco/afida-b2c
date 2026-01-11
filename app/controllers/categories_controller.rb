class CategoriesController < ApplicationController
  allow_unauthenticated_access

  def show
    @category = Category.find_by!(slug: params[:id])

    # Load products in this category
    @products = Product.active
                       .catalog_products
                       .where(category: @category)
                       .includes(:category, product_photo_attachment: :blob)
                       .order(position: :asc, id: :asc)

    # Redirect to product page if only one product in category
    if @products.count == 1
      redirect_to product_path(@products.first.slug, request.query_parameters), status: :moved_permanently
    end
  end
end
