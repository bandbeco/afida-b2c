class Category < ApplicationRecord
  BRANDED_PRODUCTS_SLUG = "branded-products".freeze

  # Old slugs that config/routes.rb still 301s at the route layer (legacy flat
  # category paths). A category taking one of these slugs would have its
  # canonical URL hijacked by the static redirect before the app ever runs.
  # Renamed slugs handled by slug history (CategorySlugRedirect) do NOT belong
  # here: reclaiming those is safe because the shadowing redirect row is
  # removed automatically. Keep in sync with the redirect map in
  # config/routes.rb.
  RESERVED_REDIRECT_SLUGS = %w[
    cups-and-lids takeaway-containers takeaway-extras plates-trays
    bagasse-eco-range
  ].freeze

  acts_as_list scope: :parent_id

  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, class_name: "Category", foreign_key: :parent_id, dependent: :restrict_with_error

  has_many :products
  has_many :collection_category_guides, dependent: :destroy
  has_many :slug_redirects, class_name: "CategorySlugRedirect", dependent: :destroy
  has_one_attached :image

  after_save :sync_slug_redirects

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :slug, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, message: "must contain only lowercase letters, numbers, and hyphens" },
                   exclusion: { in: RESERVED_REDIRECT_SLUGS, message: "is reserved by a permanent redirect (see config/routes.rb)" },
                   if: :slug_changed?
  validate :parent_cannot_be_self
  validate :max_nesting_depth

  scope :browsable, -> { where.not(slug: BRANDED_PRODUCTS_SLUG) }
  scope :top_level, -> { where(parent_id: nil) }
  scope :subcategories, -> { where.not(parent_id: nil) }

  # Resolves a slug to its category, following slug history for renamed slugs.
  # Every controller that turns a URL slug into a Category must use this so
  # admin renames 301 instead of 404ing (June 2026 incident).
  def self.find_by_slug_or_redirect(slug)
    find_by(slug: slug) || CategorySlugRedirect.find_by(old_slug: slug)&.category
  end

  def self.find_by_slug_or_redirect!(slug)
    find_by_slug_or_redirect(slug) ||
      raise(ActiveRecord::RecordNotFound.new("Couldn't find Category with slug #{slug.inspect}", name, :slug, slug))
  end

  def generate_slug
    if slug.blank? && name.present?
      self.slug = name.parameterize
    end
  end

  def to_param
    slug
  end

  # Browser-tab / SERP title with a branded fallback, mirroring
  # meta_description_with_fallback.
  def meta_title_with_fallback
    meta_title.presence || "#{name} | Afida"
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
  def sync_slug_redirects
    return unless saved_change_to_slug?

    # A redirect must never shadow a live slug (applies on create and rename).
    CategorySlugRedirect.where(old_slug: slug).destroy_all

    previous_slug = saved_change_to_slug.first
    return if previous_slug.blank?

    # The latest occupant of a vacated slug owns its redirect. Repointing an
    # existing row (instead of destroy + create!) keeps the ownership transfer
    # explicit and keeps uniqueness collisions out of the admin's rename.
    redirect = CategorySlugRedirect.find_or_initialize_by(old_slug: previous_slug)
    redirect.update!(category: self) unless redirect.persisted? && redirect.category_id == id
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
