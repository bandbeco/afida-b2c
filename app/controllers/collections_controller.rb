class CollectionsController < ApplicationController
  allow_unauthenticated_access

  def index
    @collections = Collection.regular
                             .featured
                             .by_position
                             .includes(image_attachment: :blob)
  end

  def show
    @collection = Collection.find_by!(slug: params[:slug])

    @products = @collection.visible_products
                           .includes(:category, product_photo_attachment: :blob)
                           .order("collection_items.position ASC")
  end
end
