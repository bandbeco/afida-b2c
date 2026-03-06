class CategoriesController < ApplicationController
  allow_unauthenticated_access

  def show
    @category = Category.find_by!(slug: params[:id])

    # For parent categories, load products from all subcategories
    # For leaf categories (subcategories), load only direct products
    categories_scope = if @category.children.any?
      [ @category ] + @category.children
    else
      [ @category ]
    end

    @products = Product.active
                       .catalog_products
                       .where(category: categories_scope)
                       .includes(:category, product_photo_attachment: :blob)
                       .order(position: :asc, id: :asc)

    # Redirect to product page if only one product in category
    if @products.count == 1
      redirect_to product_path(@products.first.slug, request.query_parameters), status: :moved_permanently
    end
  end
end
