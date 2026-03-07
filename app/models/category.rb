class Category < ApplicationRecord
  BRANDED_PRODUCTS_SLUG = "branded-products".freeze

  acts_as_list scope: :parent_id

  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, class_name: "Category", foreign_key: :parent_id, dependent: :restrict_with_error

  has_many :products
  has_one_attached :image

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validate :parent_cannot_be_self
  validate :max_nesting_depth

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

  private

  def parent_cannot_be_self
    if parent_id.present? && parent_id == id
      errors.add(:parent, "cannot be the category itself")
    end
  end

  def max_nesting_depth
    if parent.present? && parent.parent_id.present?
      errors.add(:parent, "cannot nest more than two levels deep")
    end
  end
end
