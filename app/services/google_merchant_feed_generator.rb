class GoogleMerchantFeedGenerator
  GOOGLE_TAXONOMY_MAP = ProductFeedAttributes::GOOGLE_TAXONOMY_MAP

  def initialize(products = Product.includes(:product_family, category: :parent).with_attached_product_photo.active)
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
    attributes = ProductFeedAttributes.new(product)

    xml.item do
      # Required fields
      xml["g"].id product.sku
      xml["g"].title attributes.title
      xml["g"].description attributes.description
      xml["g"].link Rails.application.routes.url_helpers.product_url(product)
      xml["g"].image_link attributes.image_url
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
      google_category_id = attributes.google_product_category
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
        xml["g"].item_group_id attributes.item_group_id

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
end
