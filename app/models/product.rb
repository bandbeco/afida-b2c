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
  scope :quick_add_eligible, -> { where(product_type: "standard") }
  scope :standard, -> { where(product_type: "standard") }
  scope :branded, -> { where(product_type: "customizable_template") }

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

    # Truncate query to prevent excessively long searches
    truncated_query = query.to_s.truncate(100, omission: "")
    sanitized_query = sanitize_sql_like(truncated_query)
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
  validates :slug, presence: true, uniqueness: { scope: :product_type }
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
  # Optimized to use loaded association when available (prevents N+1)
  def price_range
    # Use loaded association if available, otherwise query
    variants = active_variants.loaded? ? active_variants.to_a : active_variants
    prices = variants.map(&:price)
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

  # Description fallback methods - T018-T020
  # Returns short description with fallback to truncated standard/detailed
  def description_short_with_fallback
    return description_short if description_short.present?
    return truncate_to_words(description_standard, 15) if description_standard.present?
    truncate_to_words(description_detailed, 15) if description_detailed.present?
  end

  # Returns standard description with fallback to truncated detailed
  def description_standard_with_fallback
    return description_standard if description_standard.present?
    truncate_to_words(description_detailed, 35) if description_detailed.present?
  end

  # Returns detailed description (no fallback needed - longest form)
  def description_detailed_with_fallback
    description_detailed
  end

  # Extracts option names and values from variant option_values JSON
  # Returns only options with multiple distinct values (single-value options are excluded)
  # Sorted by priority order: material → type → size → colour
  # Example: { "size" => ["8oz", "12oz"], "colour" => ["White", "Black"] }
  def extract_options_from_variants
    option_counts = Hash.new { |h, k| h[k] = Set.new }

    active_variants.each do |variant|
      variant.option_values&.each do |key, value|
        option_counts[key] << value
      end
    end

    # Filter to options with multiple values, sort by priority
    priority = %w[material type size colour]
    option_counts
      .select { |_, values| values.size > 1 }
      .sort_by { |key, _| priority.index(key) || 999 }
      .to_h
      .transform_values(&:to_a)
  end

  # Returns variant data formatted for the variant selector JavaScript component
  # Includes all fields needed for option filtering and cart submission
  # Note: image_url is set to nil here; controller should populate it using url_for
  def variants_for_selector
    active_variants.map do |v|
      {
        id: v.id,
        sku: v.sku,
        price: v.price.to_f,
        pac_size: v.pac_size,
        option_values: v.option_values,
        pricing_tiers: v.pricing_tiers,
        image_url: nil # Populated by controller with proper URL helpers
      }
    end
  end

  private

  # T021: Truncates text to N words, adds ellipsis if truncated
  def truncate_to_words(text, word_count)
    return nil if text.blank?
    words = text.split
    return text if words.length <= word_count
    words.first(word_count).join(" ") + "..."
  end
end
