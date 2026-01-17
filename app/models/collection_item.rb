# Join table linking collections to products with ordering support.
#
# Each CollectionItem represents a product's membership in a collection,
# with a position field for ordering products within the collection.
#
# Constraints:
# - A product can only appear once in each collection (unique index)
# - Position is scoped to collection_id for acts_as_list ordering
#
class CollectionItem < ApplicationRecord
  acts_as_list scope: :collection

  belongs_to :collection
  belongs_to :product

  validates :collection_id, uniqueness: { scope: :product_id, message: "already contains this product" }
end
