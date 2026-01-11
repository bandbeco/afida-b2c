# frozen_string_literal: true

# Join table connecting Product to ProductOptionValue
# Enables proper normalization of option data with support for display labels
#
# == Schema
#   product_variant_id       - The product this option assignment belongs to (legacy column name)
#   product_option_value_id  - The specific option value (e.g., "8oz" size)
#   product_option_id        - Denormalized from product_option_value for constraint
#
# == Constraints
#   - One value per option type per product (unique on product_id + option_id)
#   - Prevents duplicate exact assignments (unique on product_id + value_id)
#
class VariantOptionValue < ApplicationRecord
  # ==========================================================================
  # Associations
  # ==========================================================================

  belongs_to :product, foreign_key: :product_variant_id
  belongs_to :product_option_value
  belongs_to :product_option

  # ==========================================================================
  # Validations
  # ==========================================================================

  # Ensure only one value per option type per product
  # This provides model-level validation in addition to the database constraint
  validates :product_option_id,
            uniqueness: {
              scope: :product_variant_id,
              message: "already has a value for this option"
            }

  # ==========================================================================
  # Callbacks
  # ==========================================================================

  # Auto-populate product_option_id from the associated product_option_value
  # This denormalization enables the one-value-per-option database constraint
  before_validation :set_product_option_from_value, on: :create

  private

  def set_product_option_from_value
    return if product_option_id.present?
    return unless product_option_value.present?

    self.product_option_id = product_option_value.product_option_id
  end
end
