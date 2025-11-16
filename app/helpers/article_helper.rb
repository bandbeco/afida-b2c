module ArticleHelper
  # Generate Schema.org Article structured data for blog posts
  def article_structured_data(content_item)
    data = {
      "@context": "https://schema.org",
      "@type": "Article",
      "headline": content_item.title,
      "datePublished": content_item.published_at.iso8601,
      "dateModified": content_item.updated_at.iso8601,
      "author": {
        "@type": "Organization",
        "name": "Afida Editorial Team"
      },
      "publisher": {
        "@type": "Organization",
        "name": "Afida",
        "logo": {
          "@type": "ImageObject",
          "url": root_url.chomp("/") + vite_asset_path("images/logo.svg")
        }
      }
    }

    # Add article body excerpt (first 200 characters)
    if content_item.body.present?
      excerpt = content_item.body.gsub(/[#*_\[\]]/, "").strip.truncate(200, separator: " ")
      data[:articleBody] = excerpt
    end

    # Add description if available
    if content_item.meta_description.present?
      data[:description] = content_item.meta_description
    end

    # Add header image if available
    if content_item.header_image_url.present?
      data[:image] = content_item.header_image_url
    end

    data.to_json
  end

  # Render markdown to HTML using Redcarpet with XSS protection
  def render_markdown(markdown_text)
    return "" if markdown_text.blank?

    # Use safe renderer that filters HTML
    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,  # CRITICAL: Filter raw HTML to prevent XSS
      hard_wrap: true,
      link_attributes: { target: "_blank", rel: "noopener noreferrer" }
    )

    markdown = Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      superscript: true
    )

    # Sanitize output as additional XSS protection layer
    sanitize(markdown.render(markdown_text), tags: %w[p br strong em ul ol li h1 h2 h3 h4 h5 h6 a blockquote code pre table thead tbody tr th td], attributes: %w[href target rel])
  end
end
