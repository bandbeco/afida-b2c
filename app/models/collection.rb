# Represents a curated group of products organized by audience or use case.
#
# Collections slice the catalog horizontally (by audience/context), unlike Categories
# which slice vertically (by product type). A product belongs to ONE category
# but can appear in MANY collections.
#
# Key relationships:
# - has_many :collection_items - Join table entries
# - has_many :products, through: :collection_items - Products in this collection
# - has_one_attached :image - Collection hero image
#
# Collection types:
# - Regular collections (featured=true): Shown on /collections index
# - Sample packs (sample_pack=true): Shown on /samples page instead
#
# URL structure:
# - Uses slugs for SEO-friendly URLs
# - Example: /collections/coffee-shop-essentials
#
class Collection < ApplicationRecord
  acts_as_list

  has_many :collection_items, -> { order(:position) }, dependent: :destroy
  has_many :products, through: :collection_items

  has_one_attached :image

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :sample_pack }

  scope :featured, -> { where(featured: true) }
  scope :sample_packs, -> { where(sample_pack: true) }
  scope :regular, -> { where(sample_pack: false) }
  scope :by_position, -> { order(:position) }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  def to_param
    slug
  end

  # Returns products that are active and visible in catalog (standard products only)
  def visible_products
    products.active.standard
  end

  # Returns sample-eligible products (for sample packs)
  def sample_eligible_products
    visible_products.sample_eligible
  end

  private

  def generate_slug
    self.slug = name.parameterize
  end
end
