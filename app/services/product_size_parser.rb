# frozen_string_literal: true

# Parses a Product#size label into a sortable volume in millilitres.
#
# Used by the volume_in_ml backfill task and anywhere a numeric capacity is
# needed for ordering. Returns nil for size strings that don't represent
# capacity (lengths, "Small/Medium/Large", "X-Cup", etc.) so callers can
# fall back to other ordering keys without a misleading 0.
class ProductSizeParser
  # Imperial fluid ounce. The catalog uses UK fl oz (e.g. "12oz / 340ml"
  # → 12 × 28.4131 ≈ 341), not US fl oz (which would yield 355ml).
  ML_PER_OZ = 28.4131

  def self.parse(input)
    return nil if input.nil?

    str = input.to_s.strip
    return nil if str.empty?

    # Prefer ml when present — it's the explicit, no-conversion-needed value.
    # `(\d+)\s*ml` matches the number that's *adjacent* to "ml", not just any
    # number that precedes it elsewhere in the string. So "8oz / 227ml" → 227.
    # For ranges like "500-1000ml", we then take the lower bound by re-scanning.
    if str.match?(/\d+\s*ml/i)
      ml_value = ml_with_lower_bound(str)
      return ml_value if ml_value
    end

    if str.match?(/\d+(?:\.\d+)?\s*oz/i)
      oz_value = oz_with_lower_bound(str)
      return (oz_value * ML_PER_OZ).round if oz_value
    end

    nil
  end

  # In a hyphenated range like "500-1000ml" or "8-12oz", take the lower bound
  # so the product sorts with its smallest-cohort siblings. Otherwise return
  # the number adjacent to the unit (so "8oz / 227ml" returns 227 for ml).
  def self.ml_with_lower_bound(str)
    range_match = str.match(/(\d+)\s*-\s*\d+\s*ml/i)
    return range_match[1].to_i if range_match

    str[/(\d+)\s*ml/i, 1]&.to_i
  end

  def self.oz_with_lower_bound(str)
    range_match = str.match(/(\d+(?:\.\d+)?)(?:\s*oz)?\s*-\s*\d+(?:\.\d+)?\s*oz/i)
    return range_match[1].to_f if range_match

    str[/(\d+(?:\.\d+)?)\s*oz/i, 1]&.to_f
  end
end
