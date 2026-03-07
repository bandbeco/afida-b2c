class Category < ApplicationRecord
  BRANDED_PRODUCTS_SLUG = "branded-products".freeze

  acts_as_list scope: :parent_id

  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, class_name: "Category", foreign_key: :parent_id

  has_many :products
  has_one_attached :image

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  scope :browsable, -> { where.not(slug: BRANDED_PRODUCTS_SLUG) }
  scope :top_level, -> { where(parent_id: nil) }
  scope :subcategories, -> { where.not(parent_id: nil) }

  def generate_slug
    if slug.blank? && name.present?
      self.slug = name.parameterize
    end
  end

  def to_param
    slug
  end
end
