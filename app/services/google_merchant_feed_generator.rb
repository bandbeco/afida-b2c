class GoogleMerchantFeedGenerator
  # Google Product Taxonomy IDs mapped to category slugs
  # Full taxonomy: https://www.google.com/basepages/producttype/taxonomy-with-ids.en-GB.txt
  GOOGLE_TAXONOMY_MAP = {
    # Cups & Drinks
    "hot-cups" => "2951",          # Food Service > Cups (Disposable)
    "cold-cups" => "2951",         # Food Service > Cups (Disposable)
    "cup-lids" => "2951",          # Food Service > Cups (Disposable)
    "cup-accessories" => "2951",   # Food Service > Cups (Disposable)
    "ice-cream-cups" => "2951",    # Food Service > Cups (Disposable)
    "straws" => "4216",            # Food Service > Straws
    "cups-and-drinks" => "2951",   # Food Service > Cups (Disposable)
    # Hot Food
    "food-containers" => "4005",   # Food Service > Food Containers (Disposable)
    "takeaway-boxes" => "4005",    # Food Service > Food Containers (Disposable)
    "soup-containers" => "4005",   # Food Service > Food Containers (Disposable)
    "pizza-boxes" => "4005",       # Food Service > Food Containers (Disposable)
    "bagasse-containers" => "4005", # Food Service > Food Containers (Disposable)
    "hot-food" => "4005",          # Food Service > Food Containers (Disposable)
    # Cold Food & Salads
    "salad-boxes" => "4005",       # Food Service > Food Containers (Disposable)
    "deli-pots" => "4005",         # Food Service > Food Containers (Disposable)
    "sandwich-and-wrap-boxes" => "4005", # Food Service > Food Containers (Disposable)
    "cold-food-and-salads" => "4005",    # Food Service > Food Containers (Disposable)
    # Tableware
    "cutlery" => "4004",           # Food Service > Cutlery (Disposable)
    "napkins" => "4003",           # Food Service > Napkins (Disposable)
    "plates-and-trays" => "4002",  # Food Service > Plates (Disposable)
    "aluminium-containers" => "4005", # Food Service > Food Containers (Disposable)
    "tableware" => "4002",         # Food Service > Plates (Disposable)
    # Bags & Wraps
    "bags" => "4279",              # Food Service > Bags (Disposable)
    "natureflex-bags" => "4279",   # Food Service > Bags (Disposable)
    "greaseproof-and-wraps" => "4279", # Food Service > Bags (Disposable)
    "bags-and-wraps" => "4279",    # Food Service > Bags (Disposable)
    # Supplies & Essentials
    "bin-liners" => "623",         # Bin Liners
    "gloves-and-cleaning" => "2228", # Cleaning Supplies
    "labels-and-stickers" => "956", # Labels
    "till-rolls" => "959",         # Receipt Paper
    "supplies-and-essentials" => "623"
  }.freeze

  def initialize(products = Product.includes(:category, :product_family).with_attached_product_photo.active)
    @products = products
  end

  def generate_xml
    builder = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
      xml.rss(version: "2.0", "xmlns:g" => "http://base.google.com/ns/1.0") do
        xml.channel do
          xml.title "Afida Product Feed"
          xml.description "Afida Product Feed for Google Merchant Center"
          xml.link Rails.application.routes.url_helpers.shop_url

          @products.each do |product|
            next unless product.product_photo.attached? || product.lifestyle_photo.attached?

            generate_product_item(xml, product)
          end
        end
      end
    end

    builder.to_xml
  end

  private

  def generate_product_item(xml, product)
    xml.item do
      # Required fields
      xml["g"].id product.sku
      xml["g"].title optimized_title(product)
      xml["g"].description optimized_description(product)
      xml["g"].link Rails.application.routes.url_helpers.product_url(product)
      xml["g"].image_link product_image_url(product)
      xml["g"].availability product.in_stock? ? "in_stock" : "out_of_stock"
      if product.pricing_tiers.present?
        xml["g"].price "#{product.pricing_tiers.first['price']} GBP"
        xml["g"].unit_pricing_measure "#{product.pricing_tiers.first['quantity']} ct"
      else
        xml["g"].price "#{product.price} GBP"
        xml["g"].unit_pricing_measure "#{product.pac_size} ct" if product.pac_size.present?
      end

      # Category (hierarchical: "Parent > Subcategory")
      if product.category
        if product.category.parent
          xml["g"].product_type "#{product.category.parent.name} > #{product.category.name}"
        else
          xml["g"].product_type product.category.name
        end
      end

      # Google Product Category (taxonomy ID)
      google_category_id = google_product_category_for(product)
      xml["g"].google_product_category google_category_id if google_category_id

      # Brand
      xml["g"].brand product.brand.presence || "Afida"

      # Product identifiers
      if product.gtin.present?
        xml["g"].gtin product.gtin
      else
        xml["g"].identifier_exists "no"
      end
      xml["g"].mpn product.sku

      # Condition
      xml["g"].condition "new"

      # Item group for products in the same family
      if product.product_family.present?
        xml["g"].item_group_id generate_item_group_id(product)

        # Add size if present
        if product.volume_in_ml.present?
          xml["g"].size "#{product.volume_in_ml}ml"
        elsif product.pac_size.present?
          xml["g"].size "Pack of #{product.pac_size}"
        end
      end

      # Color
      xml["g"].color product.colour if product.colour.present?

      # Material
      xml["g"].material product.material if product.material.present?

      # Custom labels for bid optimization
      xml["g"].custom_label_1 product.best_seller ? "yes" : "no"
      xml["g"].custom_label_3 product.category.slug if product.category # category for grouping
      xml["g"].custom_label_4 product.b2b_priority if product.b2b_priority.present?

      # Shipping (handling/transit times nested per Google spec)
      xml["g"].shipping do
        xml["g"].country "GB"
        xml["g"].service "Standard"
        xml["g"].price "6.99 GBP"
        xml["g"].min_handling_time 0
        xml["g"].max_handling_time 1
        xml["g"].min_transit_time 1
        xml["g"].max_transit_time 1
      end
    end
  end

  def optimized_title(product)
    parts = []

    # Brand (always first)
    parts << "Afida"

    # Product name
    parts << product.generated_title

    # Size/volume
    if product.volume_in_ml.present?
      parts << "#{product.volume_in_ml}ml"
    elsif product.diameter_in_mm.present?
      parts << "#{product.diameter_in_mm}mm"
    elsif product.width_in_mm.present? && product.height_in_mm.present?
      parts << "#{product.width_in_mm}x#{product.height_in_mm}mm"
    end

    # Material
    parts << product.material if product.material.present?

    # Eco feature (compostable, biodegradable, etc)
    description_text = product.description_detailed_with_fallback
    if description_text&.match?(/compostable/i)
      parts << "Compostable"
    elsif description_text&.match?(/biodegradable/i)
      parts << "Biodegradable"
    end

    # Pack size
    parts << "#{product.pac_size} Pack" if product.pac_size.present?

    # Join and truncate to 150 chars
    title = parts.join(" ")
    title.length > 150 ? title[0..146] + "..." : title
  end

  def optimized_description(product)
    # First 160 chars are critical for ads
    intro = "Afida #{product.generated_title} are perfect for eco-conscious cafes and packaging businesses."

    material_info = if product.material.present?
      " Made from #{product.material},"
    else
      ""
    end

    eco_info = " fully compostable in commercial facilities. EN 13432 certified."

    # Extended description
    quality = " Premium quality that your customers will notice - sturdy construction."
    business = " Available in bulk packs for business use with competitive wholesale pricing."
    shipping = " Free UK shipping on orders over £50."

    # Combine (ensure first 160 chars have essential info)
    first_part = intro + material_info + eco_info
    full_description = first_part + quality + business + shipping

    # Use existing description if available, otherwise use generated
    existing_description = product.description_detailed_with_fallback
    existing_description.present? ? existing_description : full_description
  end

  def generate_item_group_id(product)
    # Use product family ID if available, otherwise product ID
    if product.product_family.present?
      "FAMILY-#{product.product_family.id}"
    else
      "PROD-#{product.id}"
    end
  end

  def google_product_category_for(product)
    return nil unless product.category

    # Try the category's own slug first, then fall back to parent's slug
    GOOGLE_TAXONOMY_MAP[product.category.slug] ||
      (product.category.parent && GOOGLE_TAXONOMY_MAP[product.category.parent.slug])
  end

  def product_image_url(product)
    image = product.product_photo.attached? ? product.product_photo : product.lifestyle_photo
    return "" unless image&.attached?

    if image.content_type == "image/webp"
      Rails.application.routes.url_helpers.url_for(image.variant(format: :jpeg))
    else
      Rails.application.routes.url_helpers.url_for(image)
    end
  end
end
