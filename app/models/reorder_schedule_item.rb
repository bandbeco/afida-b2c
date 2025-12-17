class ReorderScheduleItem < ApplicationRecord
  belongs_to :reorder_schedule
  belongs_to :product_variant

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :product_variant_id, uniqueness: { scope: :reorder_schedule_id }

  delegate :product, :display_name, to: :product_variant

  def available?
    product_variant.active? && product_variant.product&.active?
  end

  def current_price
    product_variant.price
  end
end
