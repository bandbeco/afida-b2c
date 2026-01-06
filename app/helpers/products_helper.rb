# frozen_string_literal: true

module ProductsHelper
  # Option value label lookups are now handled by ProductVariant#option_labels_hash
  # which returns labels directly from the join table (variant -> product_option_value)
end
