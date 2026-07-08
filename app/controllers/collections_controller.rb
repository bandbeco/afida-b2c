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
                           .includes(:category, :product_family,
                                     product_photo_attachment: :blob,
                                     lifestyle_photo_attachment: :blob)
                           .reorder(*family_grouped_order)
  end

  def category_filter
    @collection = Collection.regular.find_by!(slug: params[:slug])
    raise ActiveRecord::RecordNotFound unless @collection.slug == Collection::VEGWARE_SLUG

    @category = Category.find_by_slug_or_redirect!(params[:category_slug])
    raise ActiveRecord::RecordNotFound if @category.parent_id.present?

    # Renamed slugs resolve via slug history; send them to the canonical URL.
    if @category.slug != params[:category_slug]
      redirect_permanently_preserving_query(category_filter_collection_path(@collection.slug, @category.slug))
      return
    end

    @products = @collection.visible_products
                           .joins(:category)
                           .where(categories: { parent_id: @category.id })
                           .includes(:category, :product_family,
                                     product_photo_attachment: :blob,
                                     lifestyle_photo_attachment: :blob)
                           .reorder(*family_grouped_order)

    @guide = CollectionCategoryGuide.for(@collection, @category)
  end

  private

  def family_grouped_order
    Product.family_grouped_order(tiebreak: Arel.sql("collection_items.position ASC"))
  end
end
