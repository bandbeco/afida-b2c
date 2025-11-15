module SeoHelper
  def product_structured_data(product, variant)
    data = {
      "@context": "https://schema.org/",
      "@type": "Product",
      "name": product.name,
      "description": product.description_standard_with_fallback,
      "brand": {
        "@type": "Brand",
        "name": "Afida"
      },
      "offers": {
        "@type": "Offer",
        "price": variant.price.to_s,
        "priceCurrency": "GBP",
        "availability": variant.in_stock? ? "https://schema.org/InStock" : "https://schema.org/OutOfStock",
        "url": product_url(product, variant_id: variant.id)
      }
    }

    # Add image if available
    if product.product_photo.attached?
      data[:image] = url_for(product.product_photo)
    end

    # Add SKU/GTIN
    data[:sku] = variant.sku if variant.sku.present?
    data[:gtin] = variant.gtin if variant.respond_to?(:gtin) && variant.gtin.present?

    data.to_json
  end

  def organization_structured_data
    logo_url = begin
      vite_asset_path("images/logo.svg")
    rescue
      # Fallback if vite_asset_path is not available (like in tests)
      "/vite/assets/images/logo.svg"
    end

    {
      "@context": "https://schema.org",
      "@type": "Organization",
      "name": "Afida",
      "url": root_url,
      "logo": logo_url,
      "contactPoint": {
        "@type": "ContactPoint",
        "contactType": "Customer Service",
        "email": "hello@afida.co.uk"
      },
      "sameAs": [
        # Add social media URLs when available
      ]
    }.to_json
  end

  def breadcrumb_structured_data(items)
    {
      "@context": "https://schema.org",
      "@type": "BreadcrumbList",
      "itemListElement": items.map.with_index do |item, index|
        {
          "@type": "ListItem",
          "position": index + 1,
          "name": item[:name],
          "item": item[:url]
        }
      end
    }.to_json
  end

  def canonical_url(url = nil)
    tag.link rel: "canonical", href: url || request.original_url
  end
end
