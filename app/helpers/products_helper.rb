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
end
