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
  validates :gtin,
            format: { with: /\A\d{8}|\d{12}|\d{13}|\d{14}\z/, message: "must be 8, 12, 13, or 14 digits" },
            uniqueness: true,
            allow_blank: true

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
    if option_values.present? && consolidated_product?
      # Build descriptive name from option_values
      # Priority order for display: material/type first, then size, then colour
      priority = %w[material type size colour]
      parts = priority.filter_map { |key| option_values[key] }
      return "#{product.name} - #{parts.join(', ')}" if parts.any?
    end

    # Standard product: use variant name
    "#{product.name} (#{name})"
  end

  # Check if this variant belongs to a consolidated product
  # Consolidated products have material or type options with multiple distinct values
  def consolidated_product?
    return false unless option_values.present?

    %w[material type].any? do |key|
      next false unless option_values.key?(key)
      # Check if siblings have different values for this key
      product.active_variants.pluck(:option_values).map { |ov| ov[key] }.compact.uniq.size > 1
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
  # Currently always returns true (stock tracking not implemented)
  # TODO: Implement proper stock tracking based on stock_quantity field
  def in_stock?
    true
    # TODO: Uncomment this when we have stock tracking
    # stock_quantity > 0
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

  # Get value for a specific option
  # Example: variant.option_value_for("size") => "8oz"
  def option_value_for(option_name)
    option_values[option_name]
  end

  # Display string of all option values for cart/order subtitles
  # For consolidated products: "Paper / 6x200mm / White" (material first)
  # For standard products: "8oz White" (simple join)
  def options_display
    return option_values.values.join(" ") unless consolidated_product?

    # For consolidated products, display in priority order with slashes
    priority = %w[material type size colour]
    parts = priority.filter_map { |key| option_values[key]&.titleize }
    parts.any? ? parts.join(" / ") : option_values.values.join(" ")
  end

  # Safe accessor methods for common option values
  # Returns nil if option not present in variant
  def size_value
    option_values["size"]
  end

  def colour_value
    option_values["colour"]
  end

  def material_value
    option_values["material"]
  end

  # Returns hash of URL parameters for linking to the product with this variant selected
  # Example: { size: "8oz", colour: "White" }
  def url_params
    params = {}
    params[:size] = option_values["size"] if option_values["size"].present?
    params[:colour] = option_values["colour"] if option_values["colour"].present?
    params
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
end
