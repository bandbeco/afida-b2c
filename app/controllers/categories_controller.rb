class CategoriesController < ApplicationController
  allow_unauthenticated_access

  def show
    @category = Category.includes(:parent, image_attachment: :blob).find_by(slug: params[:id])
    @category ||= Category.find_by_slug_or_redirect!(params[:id])

    # Enforce the canonical URL. One check covers: subcategories reached via
    # flat URLs, renamed child slugs, and stale parent slugs in nested URLs.
    canonical_path = helpers.category_browse_path(@category)
    if request.path != canonical_path
      target = canonical_path
      target += "?#{request.query_parameters.to_query}" if request.query_parameters.present?
      redirect_to target, status: :moved_permanently
      return
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
                       .includes(:category, :product_family,
                                 product_photo_attachment: :blob,
                                 lifestyle_photo_attachment: :blob)
                       .order(*Product.family_grouped_order)

    # Redirect to product page if only one product in category
    if @products.count == 1
      redirect_to product_path(@products.first.slug, request.query_parameters), status: :moved_permanently
    end
  end
end
