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
  # Example: "Pizza Box - Kraft (14 inch)"
  def display_name
    "#{product.name} (#{name})"
  end

  # Full product name with variant
  # Omits variant name if it's "Standard" or product has only one variant
  # Example: "Pizza Box - Kraft - 14 inch"
  def full_name
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

  # Display string of all option values
  # Example: "8oz White"
  def options_display
    option_values.values.join(" ")
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
end
