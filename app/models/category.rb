class Category < ApplicationRecord
  BRANDED_PRODUCTS_SLUG = "branded-products".freeze

  acts_as_list

  has_many :products
  has_one_attached :image

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  scope :browsable, -> { where.not(slug: BRANDED_PRODUCTS_SLUG) }

  def generate_slug
    if slug.blank? && name.present?
      self.slug = name.parameterize
    end
  end

  def to_param
    slug
  end
end
