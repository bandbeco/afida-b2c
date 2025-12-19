class CategoriesController < ApplicationController
  allow_unauthenticated_access

  def show
    @category = Category.find_by!(slug: params[:id])
    @products = @category.products.catalog_products

    if @products.count == 1
      redirect_to product_path(@products.first, request.query_parameters), status: :moved_permanently
      return
    end

    @products = @products.includes(:product_photo_attachment, :lifestyle_photo_attachment)
  end
end
