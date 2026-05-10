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

    @category = Category.top_level.find_by!(slug: params[:category_slug])

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
    [
      Arel.sql("product_families.sort_order ASC NULLS LAST"),
      Arel.sql("product_families.id ASC NULLS LAST"),
      Product.arel_table[:name].asc,
      Arel.sql("NULLIF(products.material, '') ASC NULLS LAST"),
      Arel.sql("NULLIF(products.colour, '') ASC NULLS LAST"),
      Arel.sql("products.volume_in_ml ASC NULLS LAST"),
      Arel.sql("collection_items.position ASC"),
      Product.arel_table[:id].asc
    ]
  end
end
