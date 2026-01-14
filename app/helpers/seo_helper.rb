module SeoHelper
  def product_structured_data(product)
    data = {
      "@context": "https://schema.org/",
      "@type": "Product",
      "name": product.generated_title,
      "description": product.description_standard_with_fallback,
      "brand": {
        "@type": "Brand",
        "name": "Afida"
      },
      "offers": {
        "@type": "Offer",
        "price": product.price.to_s,
        "priceCurrency": "GBP",
        "availability": product.in_stock? ? "https://schema.org/InStock" : "https://schema.org/OutOfStock",
        "url": product_url(product),
        "shippingDetails": {
          "@type": "OfferShippingDetails",
          "shippingRate": {
            "@type": "MonetaryAmount",
            "value": "0",
            "currency": "GBP"
          },
          "shippingDestination": {
            "@type": "DefinedRegion",
            "addressCountry": "GB"
          },
          "deliveryTime": {
            "@type": "ShippingDeliveryTime",
            "handlingTime": {
              "@type": "QuantitativeValue",
              "minValue": 0,
              "maxValue": 1,
              "unitCode": "DAY"
            },
            "transitTime": {
              "@type": "QuantitativeValue",
              "minValue": 1,
              "maxValue": 3,
              "unitCode": "DAY"
            }
          }
        }
      }
    }

    # Add image if available
    if product.product_photo.attached?
      data[:image] = url_for(product.product_photo)
    end

    # Add SKU/GTIN
    data[:sku] = product.sku if product.sku.present?
    data[:gtin] = product.gtin if product.gtin.present?

    # Add aggregate rating from Google Business Profile if configured
    if gbp_configured?
      data[:aggregateRating] = {
        "@type": "AggregateRating",
        "ratingValue": gbp_rating_data[:rating],
        "reviewCount": gbp_rating_data[:review_count],
        "bestRating": "5",
        "worstRating": "1"
      }
    end

    data.to_json
  end

  # Google Business Profile rating data accessor with memoization
  def gbp_rating_data
    @gbp_rating_data ||= {
      rating: Rails.application.credentials.dig(:google_business, :rating),
      review_count: Rails.application.credentials.dig(:google_business, :review_count),
      profile_url: Rails.application.credentials.dig(:google_business, :profile_url),
      place_id: Rails.application.credentials.dig(:google_business, :place_id)
    }
  end

  def gbp_configured?
    gbp_rating_data[:rating].present? && gbp_rating_data[:review_count].present?
  end

  def gbp_profile_url
    return gbp_rating_data[:profile_url] if gbp_rating_data[:profile_url].present?

    # Support both Place ID (ChIJ...) and CID (numeric) formats
    place_id = gbp_rating_data[:place_id]
    if place_id.present?
      if place_id.to_s.match?(/^\d+$/)
        # CID format - use Google Maps cid parameter
        "https://www.google.com/maps?cid=#{place_id}"
      else
        # Place ID format - use search local reviews
        "https://search.google.com/local/reviews?placeid=#{place_id}"
      end
    end
  end

  def organization_structured_data
    logo_url = begin
      vite_asset_path("images/logo.svg")
    rescue
      # Fallback if vite_asset_path is not available (like in tests)
      "/vite/assets/images/logo.svg"
    end

    data = {
      "@context": "https://schema.org",
      "@type": "Organization",
      "name": "Afida",
      "url": root_url,
      "logo": logo_url,
      "description": "Eco-friendly catering supplies for UK businesses",
      "contactPoint": {
        "@type": "ContactPoint",
        "contactType": "Customer Service",
        "email": "hello@afida.com"
      },
      "sameAs": [
        "https://www.linkedin.com/company/afidasupplies",
        "https://www.instagram.com/afidasupplies",
        gbp_configured? ? gbp_profile_url : nil
      ].compact
    }

    # Add aggregate rating if GBP is configured
    if gbp_configured?
      data[:aggregateRating] = {
        "@type": "AggregateRating",
        "ratingValue": gbp_rating_data[:rating].to_s,
        "reviewCount": gbp_rating_data[:review_count].to_s,
        "bestRating": "5",
        "worstRating": "1"
      }
    end

    data.to_json
  end

  # Structured data for blog posts using Schema.org Article type
  def blog_post_structured_data(blog_post)
    data = {
      "@context": "https://schema.org",
      "@type": "Article",
      "headline": blog_post.title,
      "description": blog_post.meta_description_with_fallback,
      "datePublished": blog_post.published_at.iso8601,
      "dateModified": blog_post.updated_at.iso8601,
      "author": {
        "@type": "Organization",
        "name": "Afida"
      },
      "publisher": {
        "@type": "Organization",
        "name": "Afida",
        "url": root_url
      },
      "mainEntityOfPage": {
        "@type": "WebPage",
        "@id": blog_post_url(blog_post)
      }
    }

    # Add cover image if available (important for rich snippets)
    if blog_post.cover_image.attached?
      data[:image] = url_for(blog_post.cover_image)
    end

    data.to_json
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
    # Strip query parameters by default to avoid duplicate content issues
    # Google penalizes pages where the canonical includes tracking params,
    # filters, or sort options that don't change the core content
    clean_url = url || "#{request.protocol}#{request.host_with_port}#{request.path}"
    tag.link rel: "canonical", href: clean_url
  end
end
