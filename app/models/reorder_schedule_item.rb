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
end
