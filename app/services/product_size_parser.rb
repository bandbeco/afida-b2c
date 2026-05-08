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

    if (ml = lower_bound(str, range: /(\d+)\s*-\s*\d+\s*ml/i, single: /(\d+)\s*ml/i))
      return ml.to_i
    end

    if (oz = lower_bound(str, range: /(\d+(?:\.\d+)?)(?:\s*oz)?\s*-\s*\d+(?:\.\d+)?\s*oz/i, single: /(\d+(?:\.\d+)?)\s*oz/i))
      return (oz.to_f * ML_PER_OZ).round
    end

    nil
  end

  # For "500-1000ml" or "8-12oz" return the lower bound so the product sorts
  # with its smallest-cohort siblings. Otherwise return the number adjacent
  # to the unit ("8oz / 227ml" → 227 when called for ml).
  def self.lower_bound(str, range:, single:)
    str.match(range)&.[](1) || str[single, 1]
  end
end
