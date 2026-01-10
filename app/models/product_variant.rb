# Product variant representing different options of a product (size, volume, pack size)
#
# Variants allow a single product to have multiple purchasable options.
# Each variant has its own SKU, price, and stock level.
#
# Example:
#   Product: "Pizza Box - Kraft"
#   Variants: 7", 9", 10", 12", 14" (each with unique SKU and price)
#
# Key relationships:
# - belongs_to :product - Parent product
# - has_many :cart_items - Items in shopping carts (restricted deletion)
# - has_many :order_items - Items in completed orders (nullified on deletion)
# - has_one_attached :product_photo - Variant-specific product photo
# - has_one_attached :lifestyle_photo - Variant-specific lifestyle photo
#
# Inheritance:
# - Delegates category, description, meta fields, and colour to parent product
# - Falls back to product image if variant has no specific image
#
# Google Shopping:
# - Each variant becomes a separate item with unique ID (SKU)
# - Variants of same product share item_group_id (product.base_sku)
#
class ProductVariant < ApplicationRecord
  belongs_to :product
  has_many :cart_items, dependent: :restrict_with_error
  has_many :order_items, dependent: :nullify

  # Option value associations (join table for normalized option data)
  has_many :variant_option_values, dependent: :destroy
  has_many :option_values, through: :variant_option_values, source: :product_option_value

  has_one_attached :product_photo
  has_one_attached :lifestyle_photo

  # Returns the primary photo for this variant ONLY (no product fallback)
  # Priority: product_photo first, then lifestyle_photo
  # Returns nil if no variant photos attached (caller should show placeholder)
  def primary_photo
    return product_photo if product_photo.attached?
    return lifestyle_photo if lifestyle_photo.attached?
    nil
  end

  # Returns all attached photos for this variant ONLY (no product fallback)
  def photos
    [ product_photo, lifestyle_photo ].select(&:attached?)
  end

  # Check if variant has any photos (no product fallback)
  def has_photos?
    product_photo.attached? || lifestyle_photo.attached?
  end

  scope :active, -> { where(active: true) }
  scope :by_name, -> { order(:name) }
  scope :by_position, -> { order(:position, :name) }
  scope :sample_eligible, -> { where(sample_eligible: true) }

  # Filtering and search scopes for shop page
  scope :in_categories, ->(category_slugs) {
    return all if category_slugs.blank?

    slugs = Array(category_slugs).reject(&:blank?)
    return all if slugs.empty?

    joins(product: :category).where(categories: { slug: slugs })
  }

  # Basic search on variant name and SKU (for header dropdown)
  # Fast ILIKE search without JOINs
  scope :search, ->(query) {
    return all if query.blank?

    truncated_query = query.to_s.truncate(100, omission: "")
    sanitized_query = sanitize_sql_like(truncated_query)
    where(
      "product_variants.name ILIKE :q OR product_variants.sku ILIKE :q",
      q: "%#{sanitized_query}%"
    )
  }

  # Extended search including product and category names (for shop page filtering)
  # Uses ILIKE for broader matching across related tables
  scope :search_extended, ->(query) {
    return all if query.blank?

    truncated_query = query.to_s.truncate(100, omission: "")
    sanitized_query = sanitize_sql_like(truncated_query)
    joins(product: :category).where(
      "product_variants.name ILIKE :q OR product_variants.sku ILIKE :q OR products.name ILIKE :q OR categories.name ILIKE :q",
      q: "%#{sanitized_query}%"
    )
  }

  # Filter by option value (generic scope for any option type)
  # Example: with_option("size", "8oz") or with_option("colour", "white")
  # Uses subquery to allow chaining multiple with_option scopes
  scope :with_option, ->(option_name, value) {
    return all if option_name.blank? || value.blank?

    where(id: joins(variant_option_values: { product_option_value: :product_option })
      .where(product_options: { name: option_name.to_s.downcase })
      .where(product_option_values: { value: value })
      .select(:id))
  }

  # Convenience scopes for common options
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
      joins(:product).reorder(Arel.sql("LOWER(products.name) ASC, LOWER(product_variants.name) ASC"))
    when "name_desc"
      joins(:product).reorder(Arel.sql("LOWER(products.name) DESC, LOWER(product_variants.name) DESC"))
    else
      # Default: keep existing order or use position
      all
    end
  }

  # Natural sort for variant names with numeric prefixes (e.g., 8oz, 12oz, 16oz)
  # Extracts leading digits and sorts numerically, with non-numeric names last
  # Safe: No user input interpolated - only uses static column references
  scope :naturally_sorted, -> {
    order(Arel.sql(<<~SQL.squish))
      (NULLIF(REGEXP_REPLACE(product_variants.name, '[^0-9].*', '', 'g'), ''))::integer NULLS LAST,
      product_variants.name
    SQL
  }

  validates :sku, presence: true, uniqueness: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :gtin,
            format: { with: /\A\d{8}|\d{12}|\d{13}|\d{14}\z/, message: "must be 8, 12, 13, or 14 digits" },
            uniqueness: true,
            allow_blank: true
  validate :pricing_tiers_format, if: :pricing_tiers?

  before_validation :generate_slug, if: -> { slug.blank? && name.present? && product.present? }

  # Inherit these attributes from parent product
  delegate :category, :description_standard_with_fallback, :meta_title, :meta_description, :colour, to: :product
  # Alias for backward compatibility
  alias_method :description, :description_standard_with_fallback

  # Display name for cart/order items
  # For consolidated products (with material/type options that vary), builds name from options
  # Example: "Cocktail Napkins - Paper, White"
  # For standard products, uses variant name
  # Example: "Pizza Box - Kraft (14 inch)"
  def display_name
    # Check if this is a consolidated product by looking for material/type options
    # that have multiple values across the product's variants
    hash = option_values_hash
    if hash.present? && consolidated_product?
      # Build descriptive name from option_values in priority order
      parts = PRODUCT_OPTION_PRIORITY.filter_map { |key| hash[key] }
      return "#{product.name} - #{parts.join(', ')}" if parts.any?
    end

    # Standard product: use variant name
    "#{product.name} (#{name})"
  end

  # Check if this variant belongs to a consolidated product
  # Consolidated products have material or type options with multiple distinct values
  def consolidated_product?
    hash = option_values_hash
    return false unless hash.present?

    %w[material type].any? do |key|
      next false unless hash.key?(key)
      # Check if siblings have different values for this key
      product.active_variants.map { |v| v.option_values_hash[key] }.compact.uniq.size > 1
    end
  end

  # Full product name with variant
  # Omits variant name if it's "Standard" or product has only one variant
  # Example: "Pizza Box - Kraft - 14 inch"
  def full_name
    # For consolidated products, delegate to display_name
    return display_name if consolidated_product?

    # Standard products
    parts = [ product.name ]
    parts << "- #{name}" unless name == "Standard" || product.active_variants.count == 1
    parts.join(" ")
  end

  # Check if variant is in stock
  # Returns true if stock_quantity is nil (not tracked) or greater than 0
  def in_stock?
    stock_quantity.nil? || stock_quantity > 0
  end

  # Returns hash of all product attributes for this variant
  # Used for Google Merchant feed and product detail pages
  # Filters out blank values
  def variant_attributes
    {
      material: "#{product.material}",
      width_in_mm: "#{width_in_mm}",
      height_in_mm: "#{height_in_mm}",
      depth_in_mm: "#{depth_in_mm}",
      weight_in_g: "#{weight_in_g}",
      volume_in_ml: "#{volume_in_ml}",
      diameter_in_mm: "#{diameter_in_mm}"
    }.reject { |_, value| value.blank? }
  end

  # ==========================================================================
  # Option Values Methods (querying join table)
  # ==========================================================================

  # Returns hash of option names to stored values
  # Example: { "size" => "8oz", "colour" => "White" }
  # Backwards compatible with old JSONB structure for frontend
  def option_values_hash
    @option_values_hash ||= variant_option_values
      .includes(product_option_value: :product_option)
      .each_with_object({}) do |vov, hash|
        option_name = vov.product_option.name
        hash[option_name] = vov.product_option_value.value
      end
  end

  # Returns hash of option names to display labels (with value fallback)
  # Example: { "size" => "8 oz", "colour" => "White" }
  # Uses label when present, falls back to value
  def option_labels_hash
    @option_labels_hash ||= variant_option_values
      .includes(product_option_value: :product_option)
      .each_with_object({}) do |vov, hash|
        option_name = vov.product_option.name
        pov = vov.product_option_value
        hash[option_name] = pov.label.presence || pov.value
      end
  end

  # Returns comma-separated display labels for UI
  # Example: "8 oz, White" or "Birch Wood, Fork"
  # Respects PRODUCT_OPTION_PRIORITY for ordering
  def options_summary
    labels = option_labels_hash
    return "" if labels.empty?

    # Order by priority, then include any remaining
    priority_order = PRODUCT_OPTION_PRIORITY + %w[color]
    parts = priority_order.filter_map { |key| labels[key] }

    # If priority didn't capture everything, add remaining
    remaining = labels.except(*priority_order).values
    parts.concat(remaining) if remaining.any?

    parts.join(", ")
  end

  # Get value for a specific option
  # Example: variant.option_value_for("size") => "8oz"
  def option_value_for(option_name)
    option_values_hash[option_name]
  end

  # Display string of all option values for cart/order subtitles
  # Format: "Material / Size / Colour" with titleize
  # Example: "Paper / 8oz / White", "Bamboo / 6x200mm / Natural"
  def options_display
    hash = option_values_hash
    return "" if hash.empty?

    # Display in priority order with slashes
    # Note: also checks "color" as fallback for US spelling
    priority_with_color_fallback = PRODUCT_OPTION_PRIORITY + %w[color]
    parts = priority_with_color_fallback.filter_map { |key| hash[key]&.titleize }
    parts.any? ? parts.join(" / ") : hash.values.map(&:titleize).join(" / ")
  end

  # Safe accessor methods for common option values
  # Returns nil if option not present in variant
  def size_value
    option_values_hash["size"]
  end

  def colour_value
    option_values_hash["colour"]
  end

  def material_value
    option_values_hash["material"]
  end

  # Returns hash of URL parameters for linking to the product with this variant selected
  # Includes all option_values, lowercased to match variant_selector_controller.js
  # Example: { material: "bamboo-pulp", size: "6x150mm", colour: "natural" }
  def url_params
    hash = option_values_hash
    return {} if hash.empty?

    hash.transform_keys(&:to_sym).transform_values { |v| v.to_s.downcase }
  end

  # Convert pack price to unit price for display
  # If pac_size is set, price is per pack, so divide to get per-unit price
  # Otherwise, price is already per unit
  def unit_price
    return price unless pac_size.present? && pac_size > 0
    price / pac_size
  end

  # Returns minimum order quantity in units
  def minimum_order_units
    pac_size || 1
  end

  # Returns the SKU to use for sample fulfillment
  # Uses custom sample_sku if present, otherwise derives from main SKU
  def effective_sample_sku
    sample_sku.presence || "SAMPLE-#{sku}"
  end

  # ==========================================================================
  # Display Helpers for Variant Pages
  # ==========================================================================

  # Returns meta description for SEO
  # Falls back to product description if variant has no specific description
  def variant_meta_description
    if description.present?
      description.truncate(160)
    else
      "Buy #{full_name} from Afida. Eco-friendly catering supplies at competitive prices."
    end
  end

  # Returns formatted price display for variant page
  # Format: "£36.05 / pack (1,000 units)" for pack-priced items
  # Format: "£0.0360 / unit" for unit-priced items
  def price_display
    if pac_size.present? && pac_size > 1
      "#{ActionController::Base.helpers.number_to_currency(price)} / pack (#{ActionController::Base.helpers.number_with_delimiter(pac_size)} units)"
    else
      "#{ActionController::Base.helpers.number_to_currency(price)}"
    end
  end

  # Returns unit price display for variant page
  # Useful when showing per-unit cost alongside pack price
  def unit_price_display
    ActionController::Base.helpers.number_to_currency(unit_price, precision: 4)
  end

  # Override to_param for SEO-friendly URLs
  # Enables: product_variant_path(@variant) => /products/8oz-white-single-wall-cups
  def to_param
    slug
  end

  private

  # Generates a URL-friendly slug from variant name and product name
  # Called before_validation when slug is blank
  def generate_slug
    return if slug.present?

    base = "#{name} #{product.name}".parameterize
    self.slug = ensure_unique_slug(base)
  end

  # Ensures slug uniqueness by appending counter if needed
  # Example: "8oz-cups" -> "8oz-cups-2" -> "8oz-cups-3"
  def ensure_unique_slug(base)
    slug = base
    counter = 2

    while ProductVariant.where.not(id: id).exists?(slug: slug)
      slug = "#{base}-#{counter}"
      counter += 1
    end

    slug
  end

  # Validates pricing_tiers JSON structure for volume discount tiers
  # Structure: [{ "quantity": 1, "price": "26.00" }, { "quantity": 3, "price": "24.00" }]
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
