class Category < ApplicationRecord
  BRANDED_PRODUCTS_SLUG = "branded-products".freeze

  acts_as_list scope: :parent_id

  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, class_name: "Category", foreign_key: :parent_id, dependent: :restrict_with_error

  has_many :products
  has_many :collection_category_guides, dependent: :destroy
  has_many :slug_redirects, class_name: "CategorySlugRedirect", dependent: :destroy
  has_one_attached :image

  after_update :record_slug_history

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

  # Search-snippet description with fallbacks so no category ever ships an
  # empty <meta name="description"> tag.
  def meta_description_with_fallback
    meta_description.presence ||
      description.presence ||
      "Buy #{name.downcase} in bulk from Afida. Eco-friendly catering disposables for UK food businesses, with free UK delivery over £100."
  end

  private

  # Every admin rename leaves a permanent 301 behind (the June 2026 renames
  # 404'd ~16k impressions/quarter of ranking URLs; never again).
  def record_slug_history
    return unless saved_change_to_slug?

    previous_slug = saved_change_to_slug.first
    return if previous_slug.blank?

    # A redirect must never shadow a live slug, and the latest rename wins.
    CategorySlugRedirect.where(old_slug: [ slug, previous_slug ]).destroy_all
    slug_redirects.create!(old_slug: previous_slug)
  end

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
