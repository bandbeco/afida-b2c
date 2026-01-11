class GoogleMerchantFeedGenerator
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
      xml["g"].price "#{product.price} GBP"
      xml["g"].unit_pricing_measure "#{product.pac_size}ct" if product.pac_size.present?

      # Category
      xml["g"].product_type product.category.name if product.category

      # Brand
      xml["g"].brand "Afida"

      # Product identifiers
      xml["g"].gtin product.gtin if product.gtin.present?
      xml["g"].mpn product.sku

      # Condition
      xml["g"].condition "new"

      # Item group for products in the same family
      if product.product_family.present?
        xml["g"].item_group_id generate_item_group_id(product)

        # Add size if present
        if product.volume_in_ml.present?
          xml["g"].size "#{product.volume_in_ml}ml"
        elsif product.size_value.present?
          xml["g"].size product.size_value
        elsif product.pac_size.present?
          xml["g"].size "Pack of #{product.pac_size}"
        end
      end

      # Color
      xml["g"].color product.colour_value if product.colour_value.present?

      # Material
      xml["g"].material product.material_value if product.material_value.present?

      # Custom labels for bid optimization
      xml["g"].custom_label_1 product.best_seller ? "yes" : "no"
      xml["g"].custom_label_3 product.category.slug if product.category # category for grouping
      xml["g"].custom_label_4 product.b2b_priority if product.b2b_priority.present?

      # Shipping
      xml["g"].shipping do
        xml["g"].country "GB"
        xml["g"].service "Standard"
        xml["g"].price "5.00 GBP"
      end
    end
  end

  def optimized_title(product)
    parts = []

    # Brand (always first)
    parts << "Afida"

    # Product name
    parts << product.name

    # Size/volume
    if product.volume_in_ml.present?
      parts << "#{product.volume_in_ml}ml"
    elsif product.diameter_in_mm.present?
      parts << "#{product.diameter_in_mm}mm"
    elsif product.width_in_mm.present? && product.height_in_mm.present?
      parts << "#{product.width_in_mm}x#{product.height_in_mm}mm"
    elsif product.size_value.present?
      parts << product.size_value
    end

    # Material
    parts << product.material_value if product.material_value.present?

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
    intro = "Afida #{product.name} are perfect for eco-conscious cafes and catering businesses."

    material_info = if product.material_value.present?
      " Made from #{product.material_value},"
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
    # Use product family slug or base_sku if available
    if product.product_family.present?
      "FAMILY-#{product.product_family.id}"
    elsif product.base_sku.present?
      product.base_sku
    else
      "PROD-#{product.id}"
    end
  end

  def product_image_url(product)
    image = product.product_photo.attached? ? product.product_photo : product.lifestyle_photo
    return "" unless image&.attached?

    Rails.application.routes.url_helpers.url_for(image)
  end
end
