# frozen_string_literal: true

module FaqHelper
  # Named route mappings for FAQ internal links
  # Usage in faqs.yml: "Check out our [cups and lids](/categories/cups-lids)"
  FAQ_ROUTE_MAPPINGS = {
    "/shop" => :shop_path,
    "/samples" => :samples_path,
    "/branding" => :branded_products_path,
    "/contact" => :contact_path,
    "/delivery" => :delivery_returns_path
  }.freeze

  def faq_schema_markup(categories)
    schema = {
      "@context": "https://schema.org",
      "@type": "FAQPage",
      "mainEntity": []
    }

    categories.each do |category|
      category["questions"].each do |question|
        schema[:mainEntity] << {
          "@type": "Question",
          "name": question["question"],
          "acceptedAnswer": {
            "@type": "Answer",
            "text": strip_markdown_links(question["answer"])
          }
        }
      end
    end

    content_tag(:script, schema.to_json.html_safe, type: "application/ld+json")
  end

  # Renders FAQ answer text with markdown-style links converted to HTML
  # Supports: [link text](/path) and [link text](https://example.com)
  def render_faq_answer(answer)
    return "" if answer.blank?

    # Convert markdown links [text](url) to HTML links
    html = answer.gsub(/\[([^\]]+)\]\(([^)]+)\)/) do |_match|
      text = Regexp.last_match(1)
      url = Regexp.last_match(2)

      # Use named route if available, otherwise use the URL directly
      resolved_url = FAQ_ROUTE_MAPPINGS[url] ? send(FAQ_ROUTE_MAPPINGS[url]) : url

      %(<a href="#{ERB::Util.html_escape(resolved_url)}" class="link-inline">#{ERB::Util.html_escape(text)}</a>)
    end

    html.html_safe
  end

  private

  # Strip markdown links for schema markup (plain text only)
  def strip_markdown_links(text)
    return "" if text.blank?
    text.gsub(/\[([^\]]+)\]\([^)]+\)/, '\1')
  end
end
