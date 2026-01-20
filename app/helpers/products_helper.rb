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

  # Primary text for search results - emphasizes differentiating attributes only
  # For family products: size - colour (e.g., "8oz / 280ml - Blue")
  # For standalone: product name
  def search_display_title(product)
    product.product_type
    [ product.size, product.colour ].compact_blank.join(" - ").presence || product.generated_title
  end

  # Secondary text for search results - provides context
  # For family products: material + product name (e.g., "Paper Ice Cream Cups")
  # For standalone: category name
  def search_display_subtitle(product)
    if product.brandable?
      product.branded_product_prices.map(&:size).uniq.sort_by { |size| size.to_i }.join(", ")
    else
      ([ product.material, product.name ].compact_blank.join(" ").presence || product.category&.name) + (product.pac_size.to_i > 1 ? " · Pack of " + number_with_delimiter(product.pac_size) : "")
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
