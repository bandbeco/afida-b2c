# frozen_string_literal: true

module ProductsHelper
  # Option value label lookups are handled by Product#option_labels_hash
  # which returns labels directly from the product_option_values join table.

  # Renders product description text with markdown converted to HTML.
  # Uses Redcarpet for proper markdown parsing.
  # Links automatically get the .link-inline class for accessible styling.
  def render_product_description(text)
    return "" if text.blank?

    renderer = ProductDescriptionRenderer.new(hard_wrap: true)
    markdown = Redcarpet::Markdown.new(renderer, autolink: true, no_intra_emphasis: true)
    markdown.render(text).html_safe
  end

  # Custom Redcarpet renderer that adds .link-inline class to links
  class ProductDescriptionRenderer < Redcarpet::Render::HTML
    def link(link, _title, content)
      %(<a href="#{link}" class="link-inline">#{content}</a>)
    end
  end

  # Primary text for search results
  # Format: size - brand material product_family_name
  # e.g., "10 x 200mm - Vegware Bamboo Pulp Straws"
  # Falls back to generated_title when no size
  def search_display_title(product)
    family_name = product.product_family&.name || product.name
    descriptor = [ product.brand, product.material, family_name ].compact_blank.join(" ")

    if product.size.present?
      "#{product.size} - #{descriptor}"
    else
      descriptor.presence || product.generated_title
    end
  end

  # Secondary text for search results - shows pack size only
  def search_display_subtitle(product)
    if product.brandable?
      product.branded_product_prices.map(&:size).uniq.sort_by { |size| size.to_i }.join(", ")
    elsif product.pac_size.to_i > 1
      "Pack of #{number_with_delimiter(product.pac_size)}"
    end
  end

  # Annotates each pricing tier with its per-unit price and the saving (%)
  # versus the first tier's per-unit price. Mirrors the branded configurator's
  # "£X.XXX/unit · save N%" treatment.
  #
  # For tiered products, tier["quantity"] is the number of units in the case and
  # tier["price"] is the price for the whole case, so per-unit = price / quantity.
  # Savings are measured against the first tier (the entry-level option, which
  # therefore has no badge). Returns nil savings when there is no positive saving.
  def pricing_tier_breakdown(tiers)
    return [] if tiers.blank?

    base_per_unit = nil

    tiers.map.with_index do |tier, index|
      quantity = tier["quantity"].to_i
      price = BigDecimal(tier["price"].to_s)
      per_unit = quantity.positive? ? price / quantity : price

      base_per_unit = per_unit if index.zero?

      savings_percent =
        if index.zero? || base_per_unit.nil? || base_per_unit.zero?
          nil
        else
          pct = ((base_per_unit - per_unit) / base_per_unit * 100).round
          pct.positive? ? pct : nil
        end

      {
        quantity: quantity,
        price: price,
        price_per_unit: per_unit,
        savings_percent: savings_percent
      }
    end
  end

  # Calculate the maximum volume discount percentage for branded products
  # Compares first tier (base price) to last tier within each size, returns the max
  def max_volume_discount_percentage(product)
    prices_by_size = product.branded_product_prices.order(:quantity_tier).group_by(&:size)
    return nil if prices_by_size.empty?

    max_discount = prices_by_size.map do |_size, prices|
      next 0 if prices.size < 2

      base_price = prices.first.price_per_unit
      best_price = prices.last.price_per_unit
      next 0 if base_price.zero?

      ((base_price - best_price) / base_price * 100).round
    end.max

    max_discount.positive? ? max_discount : nil
  end
end
