class GoogleMerchantFeedGenerator
  def initialize(products = Product.includes(:category, :active_variants).with_attached_product_photo)
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
            generate_product_variants(xml, product)
          end
        end
      end
    end

    builder.to_xml
  end

  private

  def generate_product_variants(xml, product)
    product.active_variants.each do |variant|
      xml.item do
        # Required fields
        xml["g"].id variant.sku
        xml["g"].title optimized_title(product, variant)
        xml["g"].description optimized_description(product, variant)
        xml["g"].link Rails.application.routes.url_helpers.product_url(product, variant_id: variant.id)
        xml["g"].image_link variant_image_url(variant, product)
        xml["g"].availability variant.in_stock? ? "in_stock" : "out_of_stock"
        xml["g"].price "#{variant.price} GBP"
        xml["g"].unit_pricing_measure "#{variant.pac_size}ct"

        # Category
        xml["g"].product_type product.category.name if product.category

        # Brand (you might want to add this to your product model)
        xml["g"].brand "Afida"

        # Product identifiers
        xml["g"].gtin variant.gtin if variant.gtin.present?
        xml["g"].mpn variant.sku

        # Condition
        xml["g"].condition "new"

        # Variant attributes
        if product.active_variants.count > 1
          xml["g"].item_group_id generate_item_group_id(product)

          # Add size if present
          if variant.volume_in_ml.present?
            xml["g"].size "#{variant.volume_in_ml}ml"
          elsif variant.name.match(/(\d+["']|\d+\s*inch)/i)
            xml["g"].size variant.name
          elsif variant.pac_size.present?
            xml["g"].size "Pack of #{variant.pac_size}"
          end
        end

        # Color stays with product, not variant
        xml["g"].color product.colour if product.colour.present?

        # Material
        xml["g"].material product.material if product.material.present?

        # Custom labels for bid optimization
        xml["g"].custom_label_0 product.profit_margin if product.profit_margin.present?
        xml["g"].custom_label_1 product.best_seller ? "yes" : "no"
        xml["g"].custom_label_2 product.seasonal_type || "year_round"
        xml["g"].custom_label_3 product.category.slug if product.category # category for grouping
        xml["g"].custom_label_4 product.b2b_priority if product.b2b_priority.present?

        # Shipping (you'll need to configure this)
        xml["g"].shipping do
          xml["g"].country "GB"
          xml["g"].service "Standard"
          xml["g"].price "5.00 GBP"
        end
      end
    end
  end

  def optimized_title(product, variant)
    parts = []

    # Brand (always first)
    parts << "Afida"

    # Product type and name
    parts << product.name

    # Size/volume
    if variant.volume_in_ml.present?
      parts << "#{variant.volume_in_ml}ml"
    elsif variant.diameter_in_mm.present?
      parts << "#{variant.diameter_in_mm}mm"
    elsif variant.width_in_mm.present? && variant.height_in_mm.present?
      parts << "#{variant.width_in_mm}x#{variant.height_in_mm}mm"
    elsif variant.name != "Standard"
      parts << variant.name
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
    parts << "#{variant.pac_size} Pack" if variant.pac_size.present?

    # Join and truncate to 150 chars
    title = parts.join(" ")
    title.length > 150 ? title[0..146] + "..." : title
  end

  def optimized_description(product, variant)
    # First 160 chars are critical for ads
    intro = "Afida #{product.name} are perfect for eco-conscious cafes and catering businesses."

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
    # Use base_sku if available, otherwise use product id
    product.base_sku || "PROD-#{product.id}"
  end

  def variant_image_url(variant, product)
    image = variant.product_photo.attached? ? variant.product_photo : product.product_photo
    return "" unless image&.attached?

    Rails.application.routes.url_helpers.url_for(image)
  end
end
