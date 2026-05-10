class CollectionCategoryGuide < ApplicationRecord
  belongs_to :collection
  belongs_to :category

  validates :collection_id, uniqueness: { scope: :category_id }

  def self.for(collection, category)
    return nil unless collection && category

    find_by(collection_id: collection.id, category_id: category.id)
  end
end
