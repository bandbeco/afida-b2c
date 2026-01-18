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
end
