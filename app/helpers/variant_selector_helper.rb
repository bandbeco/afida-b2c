# Helper methods for the variant selector component
module VariantSelectorHelper
  # Natural sort for option values that handles numeric prefixes
  # Accepts array of hashes with :value key (e.g., [{ value: "8oz", label: "8oz" }])
  # Examples: "8oz" < "12oz" < "16oz", "6x140mm" < "8x200mm"
  # Non-numeric values are sorted alphabetically at the end
  def natural_sort_options(options)
    options.sort_by do |opt|
      value = opt[:value].to_s
      # Extract leading number(s) for numeric sorting
      match = value.match(/^(\d+)/)
      if match
        [ 0, match[1].to_i, value ]
      else
        [ 1, 0, value ]
      end
    end
  end
end
