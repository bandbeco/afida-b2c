class ReorderScheduleItem < ApplicationRecord
  belongs_to :reorder_schedule
  belongs_to :product

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :product_id, uniqueness: { scope: :reorder_schedule_id }

  delegate :display_name, to: :product

  def available?
    product.active?
  end

  def current_price
    product.price
  end

  # Line total at the stored price (mirrors CartItem#subtotal_amount). The stored
  # price is frozen at setup time, so this is independent of later product changes.
  def subtotal_amount
    price * quantity
  end
end
