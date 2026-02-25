class CartItem < ApplicationRecord
  belongs_to :cart
  belongs_to :product

  has_one_attached :design

  validates :quantity, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 30000 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :price_must_be_positive_unless_sample
  validate :cart_sample_limit_not_exceeded, on: :create, if: :sample?
  validate :cannot_add_sample_when_regular_exists, on: :create, if: :sample?
  # Prevent duplicate cart items for the same product
  # Configured products are excluded as they can have different configurations
  # Tier-priced products can have multiple line items at different price points
  validates_uniqueness_of :product, scope: :cart_id, unless: -> { configured? || tiered? }
  validates :calculated_price, presence: true, if: :configured?
  validate :design_required_for_configured_products

  before_validation :set_price_from_product

  # Scopes for filtering by item type
  scope :samples, -> { where(is_sample: true) }
  scope :non_samples, -> { where(is_sample: false) }

  # Calculates subtotal: price * quantity
  # For standard products: price = pack price, quantity = number of packs
  # For branded products: price = unit price, quantity = number of units
  def subtotal_amount
    price * quantity
  end

  # Returns the current unit price from product for standard products,
  # or the configured price for branded products. This uses live pricing,
  # unlike OrderItem#unit_price which calculates from historical pac_size snapshot.
  def unit_price
    if configured?
      price
    else
      product.unit_price
    end
  end

  def line_total
    subtotal_amount
  end

  def configured?
    configuration.present?
  end

  def tiered?
    product&.pricing_tiers.present?
  end

  # Uses the is_sample boolean flag set when the item is created
  def sample?
    is_sample
  end

  # Pricing display methods for pack vs unit pricing
  # Pack-priced: standard products with pac_size > 1
  # Unit-priced: branded/configured products OR pac_size nil/1
  def pack_priced?
    !configured? && product.pac_size.present? && product.pac_size > 1
  end

  def pack_price
    pack_priced? ? price : nil
  end

  # Returns the pack size for this line item.
  # For tier-priced items, returns the matching tier's quantity (e.g. 50 or 600).
  # For standard items, delegates to product.pac_size.
  def pac_size
    if tiered?
      matching_tier = product.pricing_tiers.find { |t| BigDecimal(t["price"].to_s) == price }
      matching_tier ? matching_tier["quantity"] : product.pac_size
    else
      product.pac_size
    end
  end

  private

  def set_price_from_product
    self.price = product.price if product && price.blank?
  end

  def design_required_for_configured_products
    if configured? && !design.attached?
      errors.add(:design, "must be uploaded for custom products")
    end
  end

  # Samples (price = 0) are only allowed for sample-eligible products
  def price_must_be_positive_unless_sample
    return unless product

    if price&.zero? && !product.sample_eligible?
      errors.add(:price, "must be greater than 0")
    end
  end

  # Prevents race condition: reload cart to check current sample count at save time
  def cart_sample_limit_not_exceeded
    return unless cart

    if cart.reload.at_sample_limit?
      errors.add(:base, "Sample limit of #{Cart::SAMPLE_LIMIT} reached")
    end
  end

  # Prevents adding a sample when the regular item is already in cart
  def cannot_add_sample_when_regular_exists
    return unless cart && product

    if cart.cart_items.non_samples.exists?(product: product)
      errors.add(:base, "You already have this product in your cart")
    end
  end
end
