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

  # Secondary text for a search result row. Collapsed family rows describe the
  # variant spread (size range plus variant count); everything else falls back
  # to the per-product subtitle.
  def search_row_subtitle(row)
    if row.family?
      count = pluralize(row.variant_count, "variant")
      range = row.size_range
      range.present? ? "#{range} · #{count}" : count
    else
      search_display_subtitle(row.product)
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

  # Price line for grid product cards, led by the per-unit price so products
  # stay comparable across pack sizes. Tiered products quote the best tier's
  # rate ("From") with the minimum order quantity as context.
  def card_price_line(product)
    if product.pricing_tiers.present?
      "From #{format_unit_price(product.best_unit_price)}/unit · min #{number_with_delimiter(product.minimum_order_units)}"
    elsif product.pac_size.to_i > 1
      "#{format_unit_price(product.unit_price)}/unit · pack of #{number_with_delimiter(product.pac_size)}"
    else
      number_to_currency(product.price)
    end
  end

  # " · Yp per unit" for a multi-unit pack, blank for a single-unit pack where
  # the per-unit price is just the price itself.
  def per_unit_suffix(product)
    return "" unless product.pac_size.to_i > 1

    " · #{format_unit_price(product.unit_price)} per unit"
  end

  # Pence below a pound ("2.7p", "3p"), pounds otherwise ("£1.24")
  def format_unit_price(amount)
    if amount >= 1
      number_to_currency(amount)
    else
      "#{number_with_precision(amount * 100, precision: 1, strip_insignificant_zeros: true)}p"
    end
  end

  # Price line for a search result row. Catalog rows pair the pack price with a
  # per-unit rate so buyers can compare across pack sizes; family rows quote the
  # cheapest member with the same per-unit treatment. Reuses format_unit_price
  # from the shop card work (#237) for consistent pence/pound formatting.
  def search_price_line(row)
    product = row.product

    if row.family?
      "From #{number_to_currency(row.from_price)}#{per_unit_suffix(row.cheapest_per_unit_member)}"
    else
      "#{number_to_currency(product.price)}#{per_unit_suffix(product)}"
    end
  end

  # Factual price anchor for a brandable template row: the cheapest achievable
  # per-unit price across every branded size/tier, plus the maximum volume
  # saving when there is one.
  def branded_price_anchor(product)
    cheapest = product.branded_product_prices.minimum(:price_per_unit)
    return nil if cheapest.blank?

    anchor = "From #{format_unit_price(cheapest)} per unit"
    discount = max_volume_discount_percentage(product)
    discount ? "#{anchor} · save up to #{discount}% in volume" : anchor
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

  # Wraps each occurrence of a query word in a search result title with a
  # subtle mint-tinted <mark>, so the matched term stands out without bold
  # (banned by our design rules). Highlighting is done AFTER HTML-escaping the
  # title, and query words are matched literally (Regexp.escape), so raw user
  # input is never interpreted as HTML or as a regular expression.
  def highlight_search_match(title, query)
    escaped_title = ERB::Util.html_escape(title.to_s)

    words = query.to_s.split.map(&:strip).reject(&:blank?)
    return escaped_title if words.empty?

    # Match the already-escaped query words against the already-escaped title
    # so both sides share the same escaping and comparison stays literal. Build
    # the alternation from string sources (not a nested Regexp) so the
    # case-insensitive flag applies to every branch.
    alternation = words.map { |word| Regexp.escape(ERB::Util.html_escape(word)) }.join("|")
    pattern = Regexp.new("(#{alternation})", Regexp::IGNORECASE)

    highlighted = escaped_title.to_str.gsub(pattern) do |match|
      %(<mark class="bg-primary/10 text-inherit rounded-sm">#{match}</mark>)
    end

    highlighted.html_safe
  end
end
