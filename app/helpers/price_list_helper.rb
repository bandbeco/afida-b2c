# frozen_string_literal: true

module PriceListHelper
  # Common B2B bulk order quantities for price list quick-add
  QUANTITY_OPTIONS = [ 1, 2, 3, 5, 10 ].freeze

  def price_list_quantity_options
    QUANTITY_OPTIONS.map { |q| [ q, q ] }
  end
end
