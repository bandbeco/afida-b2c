module CollectionsHelper
  # Returns the meta title for a collection, with fallback
  def collection_meta_title(collection)
    if collection.meta_title.present?
      "#{collection.meta_title} | Afida"
    else
      "#{collection.name} | Afida"
    end
  end

  # Returns the meta description for a collection, with fallback
  def collection_meta_description(collection)
    collection.meta_description.presence || collection.description.presence || "Browse our #{collection.name} collection of eco-friendly products."
  end

  # Returns structured data JSON-LD for a collection page
  def collection_structured_data(collection)
    {
      "@context": "https://schema.org",
      "@type": "CollectionPage",
      "name": collection.name,
      "description": collection.description,
      "url": collection_url(collection),
      "breadcrumb": {
        "@type": "BreadcrumbList",
        "itemListElement": [
          {
            "@type": "ListItem",
            "position": 1,
            "name": "Home",
            "item": root_url
          },
          {
            "@type": "ListItem",
            "position": 2,
            "name": "Collections",
            "item": collections_url
          },
          {
            "@type": "ListItem",
            "position": 3,
            "name": collection.name,
            "item": collection_url(collection)
          }
        ]
      }
    }
  end

  # Returns structured data JSON-LD for a sample pack landing page
  # Uses WebPage with mainEntity of ItemList to represent the curated product set
  def sample_pack_structured_data(sample_pack, products)
    {
      "@context": "https://schema.org",
      "@type": "WebPage",
      "name": "#{sample_pack.name} Free Sample Pack",
      "description": sample_pack_meta_description(sample_pack, products),
      "url": sample_pack_url(sample_pack.slug),
      "mainEntity": {
        "@type": "ItemList",
        "name": sample_pack.name,
        "description": sample_pack.description,
        "numberOfItems": products.size,
        "itemListElement": products.each_with_index.map do |product, index|
          {
            "@type": "ListItem",
            "position": index + 1,
            "item": {
              "@type": "Product",
              "name": product.name,
              "url": product_url(product),
              "image": product.product_photo.attached? ? url_for(product.product_photo) : nil
            }.compact
          }
        end
      },
      "breadcrumb": {
        "@type": "BreadcrumbList",
        "itemListElement": [
          {
            "@type": "ListItem",
            "position": 1,
            "name": "Home",
            "item": root_url
          },
          {
            "@type": "ListItem",
            "position": 2,
            "name": "Free Samples",
            "item": samples_url
          },
          {
            "@type": "ListItem",
            "position": 3,
            "name": "#{sample_pack.name} Sample Pack",
            "item": sample_pack_url(sample_pack.slug)
          }
        ]
      }
    }
  end

  # Returns the meta title for a sample pack
  def sample_pack_meta_title(sample_pack)
    if sample_pack.meta_title.present?
      "#{sample_pack.meta_title} | Afida"
    else
      "#{sample_pack.name} | Free Sample Pack | Afida"
    end
  end

  # Returns the meta description for a sample pack
  def sample_pack_meta_description(sample_pack, products = nil)
    return sample_pack.meta_description if sample_pack.meta_description.present?
    return sample_pack.description if sample_pack.description.present?

    product_count = products&.size || 5
    shipping_cost = number_to_currency(Shipping::STANDARD_COST / 100.0)
    "Request your free #{sample_pack.name} sample pack. #{product_count} curated products delivered for just #{shipping_cost}. Try before you buy with Afida."
  end

  # Returns structured data for the collections index page (ItemList)
  def collections_index_structured_data(collections)
    {
      "@context": "https://schema.org",
      "@type": "CollectionPage",
      "name": "Collections",
      "description": "Browse our curated collections of eco-friendly catering supplies, organised by business type and use case.",
      "url": collections_url,
      "mainEntity": {
        "@type": "ItemList",
        "itemListElement": collections.each_with_index.map do |collection, index|
          {
            "@type": "ListItem",
            "position": index + 1,
            "item": {
              "@type": "CollectionPage",
              "name": collection.name,
              "description": collection.description,
              "url": collection_url(collection),
              "image": collection.image.attached? ? url_for(collection.image) : nil
            }.compact
          }
        end
      }
    }
  end
end
