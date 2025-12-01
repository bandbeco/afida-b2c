class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true

  has_one_attached :design

  validates :product_name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :price_must_be_positive_unless_sample
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :line_total, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :pac_size, numericality: { greater_than: 0 }, allow_nil: true

  before_validation :calculate_line_total

  scope :for_product, ->(product) { where(product: product) }

  def self.create_from_cart_item(cart_item, order)
    order_item = new(
      order: order,
      product: cart_item.product,
      product_variant: cart_item.product_variant,
      product_name: cart_item.product_variant.display_name,
      product_sku: cart_item.product_variant.sku,
      quantity: cart_item.quantity,
      price: cart_item.price,  # Store pack price (not unit price) for correct display
      pac_size: cart_item.product_variant.pac_size,  # Capture pack size for pricing display
      line_total: cart_item.line_total,
      configuration: cart_item.configuration
    )

    # Copy design attachment if present
    if cart_item.design.attached?
      order_item.design.attach(cart_item.design.blob)
    end

    order_item
  end

  # Calculates subtotal: price * quantity
  # For standard products: price = pack price, quantity = number of packs
  # For branded products: price = unit price, quantity = number of units
  def subtotal
    price * quantity
  end

  def product_display_name
    product_variant&.name || "Product Unavailable"
  end

  def product_still_available?
    product.present? && product.active?
  end

  def configured?
    configuration.present? && !configuration.empty?
  end

  # Pricing display methods for pack vs unit pricing
  # Pack-priced: standard products with pac_size > 1
  # Unit-priced: branded/configured products OR pac_size nil/1
  def pack_priced?
    !configured? && pac_size.present? && pac_size > 1
  end

  def pack_price
    pack_priced? ? price : nil
  end

  # Returns the unit price, calculated from historical order data (pac_size snapshot).
  # This preserves pricing at the time of order, unlike CartItem#unit_price which
  # delegates to the current product_variant.unit_price for live pricing.
  # Uses .to_f for safety: ensures float division and returns Infinity instead of
  # crashing if pac_size is somehow 0 (which validation prevents but defensive coding allows).
  def unit_price
    pack_priced? ? (price / pac_size.to_f) : price
  end

  private

  def calculate_line_total
    self.line_total = subtotal if price.present? && quantity.present?
  end

  # Samples (price = 0) are only allowed for sample-eligible variants
  def price_must_be_positive_unless_sample
    return unless product_variant

    if price.to_f == 0 && !product_variant.sample_eligible?
      errors.add(:price, "must be greater than 0")
    end
  end
end
