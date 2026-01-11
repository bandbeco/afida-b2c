# Represents a sellable product in the e-commerce catalog.
#
# Products are the primary sellable entity. Each product has its own SKU, price,
# and stock level. Products can optionally belong to a ProductFamily for grouping
# related variants (e.g., different sizes of the same cup).
#
# Key relationships:
# - belongs_to :product_family (optional) - For grouping related products
# - belongs_to :category - Product must be in a category
# - has_many :cart_items - Items in shopping carts
# - has_many :order_items - Items in completed orders
# - has_one_attached :product_photo - Main product photo
# - has_one_attached :lifestyle_photo - Lifestyle/context photo
#
# URL structure:
# - Uses slugs for SEO-friendly URLs
# - Example: /products/8oz-white-single-wall-cups
#
class Product < ApplicationRecord
  acts_as_list scope: :category
  B2B_PRIORITIES = %w[high medium low].freeze

  # ==========================================================================
  # Associations
  # ==========================================================================

  belongs_to :product_family, optional: true
  belongs_to :category, counter_cache: true
  belongs_to :organization, optional: true
  belongs_to :parent_product, class_name: "Product", optional: true, foreign_key: :parent_product_id

  has_many :cart_items, dependent: :restrict_with_error
  has_many :order_items, dependent: :nullify
  has_many :reorder_schedule_items, dependent: :destroy
  has_many :customized_instances, class_name: "Product", foreign_key: :parent_product_id

  # Compatible lids associations (for cup products)
  has_many :product_compatible_lids, dependent: :destroy
  has_many :compatible_lids, through: :product_compatible_lids, source: :compatible_lid

  # Option value associations (join table for normalized option data)
  has_many :variant_option_values, dependent: :destroy, foreign_key: :product_variant_id
  has_many :option_values, through: :variant_option_values, source: :product_option_value

  # Option assignments (links product to its applicable option types)
  has_many :option_assignments, class_name: "ProductOptionAssignment", dependent: :destroy
  has_many :options, through: :option_assignments, source: :product_option

  # Branded product pricing tiers
  has_many :branded_product_prices, dependent: :destroy

  has_one_attached :product_photo
  has_one_attached :lifestyle_photo

  # ==========================================================================
  # Enums
  # ==========================================================================

  enum :product_type, {
    standard: "standard",
    customizable_template: "customizable_template",
    customized_instance: "customized_instance"
  }, validate: true

  # ==========================================================================
  # Scopes
  # ==========================================================================

  scope :active, -> { where(active: true) }
  scope :featured, -> { where(featured: true) }
  scope :best_sellers, -> { where(best_seller: true) }
  scope :sample_eligible, -> { where(sample_eligible: true) }
  scope :by_position, -> { order(:position, :name) }
  scope :by_name, -> { order(:name) }

  # Product type scopes
  scope :catalog_products, -> { where(product_type: %w[standard customizable_template]) }
  scope :quick_add_eligible, -> { where(product_type: "standard") }
  scope :standard, -> { where(product_type: "standard") }
  scope :branded, -> { where(product_type: "customizable_template") }
  scope :customized_for_organization, ->(org) { where(product_type: "customized_instance", organization: org) }

  # Filtering scopes
  scope :in_categories, ->(category_slugs) {
    return all if category_slugs.blank?

    slugs = Array(category_slugs).reject(&:blank?)
    return all if slugs.empty?

    joins(:category).where(categories: { slug: slugs })
  }

  # Search on product name and SKU
  scope :search, ->(query) {
    return all if query.blank?

    truncated_query = query.to_s.truncate(100, omission: "")
    sanitized_query = sanitize_sql_like(truncated_query)
    where("products.name ILIKE :q OR products.sku ILIKE :q", q: "%#{sanitized_query}%")
  }

  # Extended search including category names
  scope :search_extended, ->(query) {
    return all if query.blank?

    truncated_query = query.to_s.truncate(100, omission: "")
    sanitized_query = sanitize_sql_like(truncated_query)
    joins(:category).where(
      "products.name ILIKE :q OR products.sku ILIKE :q OR categories.name ILIKE :q",
      q: "%#{sanitized_query}%"
    )
  }

  # Filter by option value
  scope :with_option, ->(option_name, value) {
    return all if option_name.blank? || value.blank?

    where(id: joins(variant_option_values: { product_option_value: :product_option })
      .where(product_options: { name: option_name.to_s.downcase })
      .where(product_option_values: { value: value })
      .select(:id))
  }

  scope :with_size, ->(size) { with_option("size", size) }
  scope :with_colour, ->(colour) { with_option("colour", colour) }
  scope :with_material, ->(material) { with_option("material", material) }

  scope :sorted, ->(sort_param) {
    case sort_param
    when "price_asc"
      reorder(price: :asc, id: :asc)
    when "price_desc"
      reorder(price: :desc, id: :asc)
    when "name_asc"
      reorder(Arel.sql("LOWER(products.name) ASC"))
    when "name_desc"
      reorder(Arel.sql("LOWER(products.name) DESC"))
    else
      all
    end
  }

  # Natural sort for names with numeric prefixes (e.g., 8oz, 12oz, 16oz)
  scope :naturally_sorted, -> {
    order(Arel.sql(<<~SQL.squish))
      (NULLIF(REGEXP_REPLACE(products.name, '[^0-9].*', '', 'g'), ''))::integer NULLS LAST,
      products.name
    SQL
  }

  # ==========================================================================
  # Validations
  # ==========================================================================

  validates :name, presence: true
  validates :sku, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :category, presence: true
  validates :gtin,
            format: { with: /\A\d{8}|\d{12}|\d{13}|\d{14}\z/, message: "must be 8, 12, 13, or 14 digits" },
            uniqueness: true,
            allow_blank: true
  validates :parent_product_id, presence: true, if: :customized_instance?
  validates :organization_id, presence: true, if: :customized_instance?
  validates :b2b_priority, inclusion: { in: B2B_PRIORITIES }, allow_nil: true

  validate :pricing_tiers_format, if: :pricing_tiers?

  # ==========================================================================
  # Callbacks
  # ==========================================================================

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  # ==========================================================================
  # Photo Methods
  # ==========================================================================

  def primary_photo
    return product_photo if product_photo.attached?
    return lifestyle_photo if lifestyle_photo.attached?
    nil
  end

  def photos
    [ product_photo, lifestyle_photo ].select(&:attached?)
  end

  def has_photos?
    product_photo.attached? || lifestyle_photo.attached?
  end

  # ==========================================================================
  # Naming & Display Methods
  # ==========================================================================

  def to_param
    slug
  end

  # Display name for the product
  # For products in a family, shows "Family Name (Product Name)"
  # For standalone products, just shows the product name
  def display_name
    if product_family.present?
      "#{product_family.name} (#{name})"
    else
      name
    end
  end

  # Full product name - same as display_name
  def full_name
    display_name
  end

  # Returns other products in the same family
  def siblings(limit: 8)
    return Product.none unless product_family_id.present?
    product_family.products.active.where.not(id: id).limit(limit)
  end

  alias_method :sibling_variants, :siblings

  # ==========================================================================
  # Pricing Methods
  # ==========================================================================

  def unit_price
    return price unless pac_size.present? && pac_size > 0
    price / pac_size
  end

  def minimum_order_units
    pac_size || 1
  end

  def price_display
    if pac_size.present? && pac_size > 1
      "#{ActionController::Base.helpers.number_to_currency(price)} / pack (#{ActionController::Base.helpers.number_with_delimiter(pac_size)} units)"
    else
      ActionController::Base.helpers.number_to_currency(price)
    end
  end

  def unit_price_display
    ActionController::Base.helpers.number_to_currency(unit_price, precision: 4)
  end

  # Returns price range for products in the same family
  # For standalone products, returns just the price
  def price_range
    if product_family.present?
      prices = product_family.products.active.pluck(:price)
      return nil if prices.empty?

      min = prices.min
      max = prices.max
      min == max ? min : [ min, max ]
    else
      price
    end
  end

  # ==========================================================================
  # Stock Methods
  # ==========================================================================

  def in_stock?
    stock_quantity.nil? || stock_quantity > 0
  end

  # ==========================================================================
  # Sample Methods
  # ==========================================================================

  def effective_sample_sku
    sample_sku.presence || "SAMPLE-#{sku}"
  end

  # ==========================================================================
  # Option Values Methods
  # ==========================================================================

  def option_values_hash
    @option_values_hash ||= variant_option_values
      .includes(product_option_value: :product_option)
      .each_with_object({}) do |vov, hash|
        option_name = vov.product_option.name
        hash[option_name] = vov.product_option_value.value
      end
  end

  def option_labels_hash
    @option_labels_hash ||= variant_option_values
      .includes(product_option_value: :product_option)
      .each_with_object({}) do |vov, hash|
        option_name = vov.product_option.name
        pov = vov.product_option_value
        hash[option_name] = pov.label.presence || pov.value
      end
  end

  def options_summary
    labels = option_labels_hash
    return "" if labels.empty?

    priority_order = PRODUCT_OPTION_PRIORITY + %w[color]
    parts = priority_order.filter_map { |key| labels[key] }
    remaining = labels.except(*priority_order).values
    parts.concat(remaining) if remaining.any?

    parts.join(", ")
  end

  def option_value_for(option_name)
    option_values_hash[option_name]
  end

  def options_display
    hash = option_values_hash
    return "" if hash.empty?

    priority_with_color_fallback = PRODUCT_OPTION_PRIORITY + %w[color]
    parts = priority_with_color_fallback.filter_map { |key| hash[key]&.titleize }
    parts.any? ? parts.join(" / ") : hash.values.map(&:titleize).join(" / ")
  end

  def size_value
    option_values_hash["size"]
  end

  def colour_value
    option_values_hash["colour"]
  end

  def material_value
    option_values_hash["material"]
  end

  def url_params
    hash = option_values_hash
    return {} if hash.empty?

    hash.transform_keys(&:to_sym).transform_values { |v| v.to_s.downcase }
  end

  # ==========================================================================
  # Description Methods
  # ==========================================================================

  def description_short_with_fallback
    return description_short if description_short.present?
    return truncate_to_words(description_standard, 15) if description_standard.present?
    truncate_to_words(description_detailed, 15) if description_detailed.present?
  end

  def description_standard_with_fallback
    return description_standard if description_standard.present?
    truncate_to_words(description_detailed, 35) if description_detailed.present?
  end

  def description_detailed_with_fallback
    description_detailed
  end

  # Alias for backward compatibility
  def description
    description_standard_with_fallback
  end

  # ==========================================================================
  # SEO Methods
  # ==========================================================================

  def variant_meta_description
    if description.present?
      description.truncate(160)
    else
      "Buy #{full_name} from Afida. Eco-friendly catering supplies at competitive prices."
    end
  end

  # ==========================================================================
  # Variant Attributes (for Google Merchant feed)
  # ==========================================================================

  def variant_attributes
    {
      material: material.to_s,
      width_in_mm: width_in_mm.to_s,
      height_in_mm: height_in_mm.to_s,
      depth_in_mm: depth_in_mm.to_s,
      weight_in_g: weight_in_g.to_s,
      volume_in_ml: volume_in_ml.to_s,
      diameter_in_mm: diameter_in_mm.to_s
    }.reject { |_, value| value.blank? }
  end

  # ==========================================================================
  # Family-related Methods (for ProductFamily grouping)
  # ==========================================================================

  # Returns available options across all products in the family
  def available_options
    return {} unless product_family.present?

    option_counts = Hash.new { |h, k| h[k] = Set.new }

    product_family.products.active.each do |product|
      product.option_values_hash.each do |key, value|
        option_counts[key] << value
      end
    end

    option_counts
      .select { |_, values| values.size > 1 }
      .sort_by { |key, _| PRODUCT_OPTION_PRIORITY.index(key) || 999 }
      .to_h
      .transform_values(&:to_a)
  end

  # Returns products in family formatted for variant selector JS
  def variants_for_selector(products = nil)
    return [] unless product_family.present?

    (products || product_family.products.active).map do |p|
      {
        id: p.id,
        sku: p.sku,
        price: p.price.to_f,
        pac_size: p.pac_size,
        option_values: p.option_values_hash,
        pricing_tiers: p.pricing_tiers,
        image_url: nil
      }
    end
  end

  private

  def truncate_to_words(text, word_count)
    return nil if text.blank?
    words = text.split
    return text if words.length <= word_count
    words.first(word_count).join(" ") + "..."
  end

  def generate_slug
    return if slug.present?

    base = name.to_s.parameterize
    self.slug = ensure_unique_slug(base)
  end

  def ensure_unique_slug(base)
    slug = base
    counter = 2

    while Product.where.not(id: id).exists?(slug: slug)
      slug = "#{base}-#{counter}"
      counter += 1
    end

    slug
  end

  def pricing_tiers_format
    return if pricing_tiers.blank?

    unless pricing_tiers.is_a?(Array)
      errors.add(:pricing_tiers, "must be an array")
      return
    end

    quantities = []
    pricing_tiers.each_with_index do |tier, i|
      unless tier.is_a?(Hash) && tier["quantity"].is_a?(Integer) && tier["quantity"] > 0
        errors.add(:pricing_tiers, "tier #{i} must have positive integer quantity")
      end

      unless tier["price"].present? && tier["price"].to_s.match?(/\A\d+\.?\d*\z/)
        errors.add(:pricing_tiers, "tier #{i} must have valid price")
      end

      if quantities.include?(tier["quantity"])
        errors.add(:pricing_tiers, "duplicate quantity #{tier['quantity']}")
      end
      quantities << tier["quantity"]
    end

    unless quantities == quantities.sort
      errors.add(:pricing_tiers, "must be sorted by quantity")
    end
  end
end
