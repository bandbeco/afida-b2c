class CartItem < ApplicationRecord
  belongs_to :cart
  belongs_to :product_variant
  has_one :product, through: :product_variant

  has_one_attached :design

  validates :quantity, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 30000 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :price_must_be_positive_unless_sample
  # Allow same variant twice: once as sample (price=0) and once as regular item (price>0)
  # Configured products can always have duplicates (different configurations)
  validates_uniqueness_of :product_variant, scope: [ :cart_id, :price ], unless: -> { configured? || sample? }
  validates :calculated_price, presence: true, if: :configured?
  validate :design_required_for_configured_products

  before_validation :set_price_from_variant

  # Calculates subtotal: price * quantity
  # For standard products: price = pack price, quantity = number of packs
  # For branded products: price = unit price, quantity = number of units
  def subtotal_amount
    price * quantity
  end

  # Returns the current unit price from product_variant for standard products,
  # or the configured price for branded products. This uses live pricing,
  # unlike OrderItem#unit_price which calculates from historical pac_size snapshot.
  def unit_price
    if configured?
      price
    else
      product_variant.unit_price
    end
  end

  def line_total
    subtotal_amount
  end

  def configured?
    configuration.present?
  end

  # A sample is a free item (price = 0) on a sample-eligible variant
  def sample?
    price.to_f.zero? && product_variant&.sample_eligible?
  end

  # Pricing display methods for pack vs unit pricing
  # Pack-priced: standard products with pac_size > 1
  # Unit-priced: branded/configured products OR pac_size nil/1
  def pack_priced?
    !configured? && product_variant.pac_size.present? && product_variant.pac_size > 1
  end

  def pack_price
    pack_priced? ? price : nil
  end

  # Delegate to product_variant for consistent interface with OrderItem
  def pac_size
    product_variant.pac_size
  end

  private

  def set_price_from_variant
    self.price = product_variant.price if product_variant && price.blank?
  end

  def design_required_for_configured_products
    if configured? && !design.attached?
      errors.add(:design, "must be uploaded for custom products")
    end
  end

  # Samples (price = 0) are only allowed for sample-eligible variants
  def price_must_be_positive_unless_sample
    return unless product_variant

    if price.to_f == 0 && !product_variant.sample_eligible?
      errors.add(:price, "must be greater than 0")
    end
  end
end
