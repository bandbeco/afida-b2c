require "csv"

module AgenticCommerce
  # Renders Afida's stock catalogue as the CSV Stripe Agentic Commerce Suite
  # ingests (see docs/plans/2026-09-02-stripe-agentic-commerce.md). Product
  # copy, images and identifiers come from the same source as the Google
  # Merchant feed so the two cannot drift.
  class ProductFeed
    COLUMNS = %w[
      id title description link image_link additional_image_link brand gtin mpn condition
      google_product_category product_category
      item_group_id item_group_title color material size
      availability inventory_not_tracked price tax_behavior
      shipping shipping_cost_basis shipping_tax_behavior free_shipping_threshold
      custom_label_1 custom_label_3
    ].freeze

    SHIPPING_SERVICE = "Standard"
    # Mainland next-working-day; off-mainland zones are priced by postcode in the
    # checkout customization hook (Phase 2), not in the feed.
    SHIPPING_SPEED_RANGE = "1-1"

    # Stock products only. Branded templates need artwork and a design review
    # an agent cannot run, so they stay website-only for now.
    def self.eligible_products
      Product.active.standard
        .includes(:category, :product_family)
        .with_attached_product_photo
        .with_attached_lifestyle_photo
    end

    def initialize(products = self.class.eligible_products)
      @products = products
    end

    def to_csv
      CSV.generate do |csv|
        csv << COLUMNS
        rows.each { |row| csv << row.values_at(*COLUMNS) }
      end
    end

    # The SKUs the CSV carries, in feed order. Recorded on the import so the
    # next push can send deletions for products that have since dropped out.
    def skus
      rows.map { |row| row["id"] }
    end

    def row_count
      rows.size
    end

    private

    def rows
      @rows ||= @products.filter_map do |product|
        next unless product.product_photo.attached? || product.lifestyle_photo.attached?

        row_for(product)
      end
    end

    def row_for(product)
      attributes = ProductFeedAttributes.new(product)
      {
        "id" => product.sku,
        "title" => attributes.title,
        "description" => plain_text(attributes.description, limit: 5000),
        "link" => Rails.application.routes.url_helpers.product_url(product),
        "image_link" => attributes.image_url,
        "additional_image_link" => attributes.additional_image_urls.join(",").presence,
        "brand" => product.brand.presence || "Afida",
        "gtin" => product.gtin.presence,
        "mpn" => product.sku,
        "condition" => "new",
        "google_product_category" => attributes.google_product_category,
        "product_category" => category_path(product.category),
        **variant_columns(product, attributes),
        "availability" => product.in_stock? ? "in_stock" : "out_of_stock",
        "inventory_not_tracked" => "true",
        "price" => format_price(list_price(product)),
        "tax_behavior" => "exclusive",
        "shipping" => shipping_rule,
        "shipping_cost_basis" => "per_order",
        "shipping_tax_behavior" => "exclusive",
        "free_shipping_threshold" => free_shipping_rule,
        "custom_label_1" => product.best_seller ? "yes" : "no",
        "custom_label_3" => product.category&.slug
      }
    end

    # Stripe wants plain text: strip any markup carried in the stored copy and
    # hold the length under Stripe's cap.
    def plain_text(text, limit:)
      ActionController::Base.helpers.strip_tags(text.to_s).squish.first(limit)
    end

    def shipping_rule
      "GB:ALL:#{SHIPPING_SERVICE}:#{SHIPPING_SPEED_RANGE}:#{format_price(Shipping.standard_cost_in_pounds)}"
    end

    def free_shipping_rule
      "GB:ALL:#{SHIPPING_SERVICE}:#{format_price(Shipping::FREE_SHIPPING_THRESHOLD)}"
    end

    # Stripe groups variants by item_group_id; a product outside a family is a
    # group of one, so it carries no group columns.
    def variant_columns(product, attributes)
      return {} unless product.product_family.present?

      {
        "item_group_id" => attributes.item_group_id,
        "item_group_title" => product.product_family.name,
        "color" => product.colour.presence,
        "material" => product.material.presence,
        "size" => variant_size(product)
      }
    end

    def variant_size(product)
      if product.volume_in_ml.present?
        "#{product.volume_in_ml}ml"
      elsif product.pac_size.present?
        "Pack of #{product.pac_size}"
      end
    end

    def category_path(category)
      return nil unless category

      [ category.parent&.name, category.name ].compact.join(" > ")
    end

    # Agents charge price x quantity, so the feed carries the single-pack tier.
    # Volume tiers stay website-only (see the plan's Decisions).
    def list_price(product)
      return product.price if product.pricing_tiers.blank?

      BigDecimal(product.pricing_tiers.first["price"].to_s)
    end

    def format_price(amount)
      format("%.2f GBP", amount)
    end
  end
end
