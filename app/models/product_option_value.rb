class ProductOptionValue < ApplicationRecord
  belongs_to :product_option

  # T037: Prevent deletion of option values that are referenced by variants
  has_many :variant_option_values, dependent: :restrict_with_error

  validates :value, presence: true
  validates :value, uniqueness: { scope: :product_option_id }

  default_scope { order(:position) }
end
