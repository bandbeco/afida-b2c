class ProductFamily < ApplicationRecord
  has_many :products, dependent: :nullify

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9-]+\z/, message: "only allows lowercase letters, numbers, and hyphens" }

  before_validation :generate_slug

  def to_param
    slug
  end

  private

  def generate_slug
    return if slug.present? || name.blank?

    base_slug = name.to_s.parameterize
    self.slug = base_slug

    # Ensure uniqueness (excluding self, so regenerating an unchanged
    # name on update doesn't suffix the record's own slug)
    counter = 1
    while ProductFamily.where.not(id: id).exists?(slug: self.slug)
      self.slug = "#{base_slug}-#{counter}"
      counter += 1
    end
  end
end
