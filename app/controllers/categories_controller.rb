class CategoriesController < ApplicationController
  allow_unauthenticated_access

  def show
    if params[:parent_slug].present?
      # Nested route: /categories/:parent_slug/:id
      @parent = Category.top_level.find_by!(slug: params[:parent_slug])
      @category = @parent.children.includes(:parent, image_attachment: :blob).find_by!(slug: params[:id])
    else
      @category = Category.includes(:parent, image_attachment: :blob).find_by!(slug: params[:id])

      # If a subcategory is accessed via flat URL, redirect to nested URL
      if @category.parent.present?
        redirect_to category_subcategory_path(@category.parent.slug, @category.slug, request.query_parameters),
                    status: :moved_permanently
        return
      end
    end

    # Eager load children to avoid separate query for .any? and iteration
    @category.children.load

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
                       .includes(:category, product_photo_attachment: :blob, lifestyle_photo_attachment: :blob)
                       .order(position: :asc, id: :asc)

    # Redirect to product page if only one product in category
    if @products.count == 1
      redirect_to product_path(@products.first.slug, request.query_parameters), status: :moved_permanently
    end
  end
end
