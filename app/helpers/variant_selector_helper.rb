# Helper methods for the variant selector component
module VariantSelectorHelper
  # Natural sort for size values that handles numeric prefixes
  # Examples: "8oz" < "12oz" < "16oz", "6x140mm" < "8x200mm"
  # Non-numeric values are sorted alphabetically at the end
  def natural_sort_sizes(values)
    values.sort_by do |value|
      # Extract leading number(s) for numeric sorting
      match = value.to_s.match(/^(\d+)/)
      if match
        [ 0, match[1].to_i, value.to_s ]
      else
        [ 1, 0, value.to_s ]
      end
    end
  end

  # Format option value for display
  # Values are displayed as-is from the database (source CSV should have proper formatting)
  def format_option_value(_option_name, value)
    return value if value.blank?

    value.strip
  end
end
