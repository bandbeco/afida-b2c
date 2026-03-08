class CollectionsController < ApplicationController
  allow_unauthenticated_access

  def index
    @collections = Collection.regular
                             .featured
                             .by_position
                             .includes(image_attachment: :blob)
  end

  def show
    @collection = Collection.regular.find_by!(slug: params[:slug])

    @products = @collection.visible_products
                           .includes(:category, product_photo_attachment: :blob, lifestyle_photo_attachment: :blob)
                           .order("collection_items.position ASC")
  end

  def category_filter
    @collection = Collection.regular.find_by!(slug: params[:slug])
    raise ActiveRecord::RecordNotFound unless @collection.slug == Collection::VEGWARE_SLUG

    @category = Category.top_level.find_by!(slug: params[:category_slug])

    @products = @collection.visible_products
                           .joins(:category)
                           .where(categories: { parent_id: @category.id })
                           .includes(:category, product_photo_attachment: :blob, lifestyle_photo_attachment: :blob)
                           .order("collection_items.position ASC")
  end
end
