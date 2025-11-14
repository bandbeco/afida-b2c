# Represents a product in the e-commerce catalog.
#
# Products are the base model for items sold in the shop. Each product can have
# multiple variants (different sizes, volumes, pack sizes) but colors are
# separate products.
#
# Key relationships:
# - belongs_to :category - Product must be in a category
# - has_many :variants - ProductVariant records (different sizes/options)
# - has_one_attached :product_photo - Main product photo
# - has_one_attached :lifestyle_photo - Lifestyle/context photo
#
# URL structure:
# - Uses slugs for SEO-friendly URLs (generated from name/SKU/colour)
# - Example: /products/pizza-box-kraft
#
# Default scope:
# - Only returns active products ordered by position, then name
# - Use Product.unscoped to access inactive products
#
class Product < ApplicationRecord
  acts_as_list scope: :category_id

  PROFIT_MARGINS = %w[high medium low].freeze
  SEASONAL_TYPES = %w[year_round seasonal holiday].freeze
  B2B_PRIORITIES = %w[high medium low].freeze

  default_scope { where(active: true).order(:position, :name) }
  scope :featured, -> { where(featured: true) }
  scope :catalog_products, -> { where(product_type: [ "standard", "customizable_template" ]) }
  scope :customized_for_organization, ->(org) { unscoped.where(product_type: "customized_instance", organization: org) }

  # Filtering and search scopes
  scope :in_categories, ->(category_slugs) {
    return all if category_slugs.blank?

    # Handle array of category slugs
    slugs = Array(category_slugs).reject(&:blank?)
    return all if slugs.empty?

    joins(:category).where(categories: { slug: slugs })
  }

  scope :search, ->(query) {
    return all if query.blank?

    sanitized_query = sanitize_sql_like(query)
    where("name ILIKE ? OR sku ILIKE ? OR colour ILIKE ?",
          "%#{sanitized_query}%",
          "%#{sanitized_query}%",
          "%#{sanitized_query}%")
  }

  scope :sorted, ->(sort_param) {
    case sort_param
    when "price_asc"
      # Sort by minimum price (the "from" price displayed on cards)
      # NULLS LAST: products without variants appear at end
      reorder(
        Arel.sql("(SELECT MIN(price) FROM product_variants WHERE product_variants.product_id = products.id AND product_variants.active = true) ASC NULLS LAST, products.name ASC")
      )
    when "price_desc"
      # Sort by minimum price descending (the "from" price displayed on cards)
      # NULLS LAST: products without variants appear at end
      reorder(
        Arel.sql("(SELECT MIN(price) FROM product_variants WHERE product_variants.product_id = products.id AND product_variants.active = true) DESC NULLS LAST, products.name ASC")
      )
    when "name_asc"
      reorder(Arel.sql("LOWER(products.name) ASC"))
    when "name_desc"
      reorder(Arel.sql("LOWER(products.name) DESC"))
    else  # "relevance" or nil or blank
      # Keep default scope ordering (position ASC, name ASC)
      all
    end
  }

  belongs_to :category, counter_cache: true
  belongs_to :organization, optional: true
  belongs_to :parent_product, class_name: "Product", optional: true

  has_many :variants, dependent: :destroy, class_name: "ProductVariant"
  has_many :active_variants, -> { active.by_position }, class_name: "ProductVariant"
  has_many :customized_instances, class_name: "Product", foreign_key: :parent_product_id
  has_many :option_assignments, class_name: "ProductOptionAssignment", dependent: :destroy
  has_many :options, through: :option_assignments, source: :product_option
  has_many :branded_product_prices, dependent: :destroy
  has_many :product_compatible_lids, dependent: :destroy
  has_many :compatible_lids,
           -> { unscope(:order).order("product_compatible_lids.sort_order") },
           through: :product_compatible_lids,
           source: :compatible_lid

  accepts_nested_attributes_for :variants, allow_destroy: true, reject_if: :all_blank

  has_one_attached :product_photo
  has_one_attached :lifestyle_photo

  # Returns the primary photo (with smart fallback)
  # Priority: product_photo first, then lifestyle_photo
  def primary_photo
    return product_photo if product_photo.attached?
    return lifestyle_photo if lifestyle_photo.attached?
    nil
  end

  # Returns all attached photos as an array
  # Useful for galleries or carousels on detail pages
  def photos
    [ product_photo, lifestyle_photo ].select(&:attached?)
  end

  # Check if any photo is available
  def has_photos?
    product_photo.attached? || lifestyle_photo.attached?
  end

  enum :product_type, {
    standard: "standard",
    customizable_template: "customizable_template",
    customized_instance: "customized_instance"
  }, validate: true

  before_validation :generate_slug

  validates :name, :category, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :parent_product_id, presence: true, if: :customized_instance?
  validates :organization_id, presence: true, if: :customized_instance?

  validates :profit_margin, inclusion: { in: PROFIT_MARGINS }, allow_nil: true
  validates :seasonal_type, inclusion: { in: SEASONAL_TYPES }, allow_nil: true
  validates :b2b_priority, inclusion: { in: B2B_PRIORITIES }, allow_nil: true

  # Generates a SEO-friendly slug from product attributes
  # Combines SKU, name, and colour to create unique, descriptive URL
  # Example: "PIZB", "Pizza Box", "Kraft" → "pizb-pizza-box-kraft"
  def generate_slug
    if slug.blank? && name.present?
      slug_parts = [ sku, name, colour ].compact.reject(&:blank?).join(" ")
      self.slug = slug_parts.parameterize
    end
  end

  # Override to_param to use slug in URLs instead of ID
  # Makes URLs like /products/pizza-box-kraft instead of /products/123
  def to_param
    slug
  end

  # Returns the first active variant
  # Useful for products with single variants or to show a default option
  def default_variant
    active_variants.first
  end

  # Calculates price range across all active variants
  # Returns:
  # - nil if no variants
  # - Single price if all variants have same price
  # - [min, max] array if variant prices differ
  def price_range
    prices = active_variants.pluck(:price)
    return nil if prices.empty?

    min = prices.min
    max = prices.max

    min == max ? min : [ min, max ]
  end

  # Returns the default compatible lid product
  # Returns nil if no default is set
  def default_compatible_lid
    product_compatible_lids.find_by(default: true)&.compatible_lid
  end

  # Check if this product has any compatible lids
  def has_compatible_lids?
    product_compatible_lids.exists?
  end
end
