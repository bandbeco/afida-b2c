require "test_helper"
require "csv"

module AgenticCommerce
  class ProductFeedTest < ActiveSupport::TestCase
    setup do
      Rails.application.routes.default_url_options[:host] = "example.com"
      Rails.application.routes.default_url_options[:protocol] = "https"
    end

    test "renders a standard product with the required columns" do
      product = products(:one)
      attach_product_photo(product)

      rows = parse(ProductFeed.new(Product.where(id: product.id)).to_csv)

      assert_equal 1, rows.size
      row = rows.first
      assert_equal "BUBL-POP-11", row["id"]
      assert_includes row["title"], "Afida"
      assert row["description"].present?
      assert_equal "https://example.com/products/product-1", row["link"]
      assert_match %r{\Ahttps://example.com/.+}, row["image_link"]
      assert_equal "Afida", row["brand"]
      assert_equal "BUBL-POP-11", row["mpn"]
      assert_equal "new", row["condition"]
      assert_equal "in_stock", row["availability"]
      assert_equal "true", row["inventory_not_tracked"]
      assert_equal "9.99 GBP", row["price"]
      assert_equal "exclusive", row["tax_behavior"]
    end

    test "default product set has stock products only, not branded or inactive ones" do
      attach_product_photo(products(:one))
      attach_product_photo(products(:branded_template_variant))
      attach_product_photo(products(:inactive_product))

      ids = parse(ProductFeed.new.to_csv).map { |row| row["id"] }

      assert_includes ids, products(:one).sku
      assert_not_includes ids, products(:branded_template_variant).sku
      assert_not_includes ids, products(:inactive_product).sku
    end

    test "skips a product with no photo because image_link is required" do
      product = products(:two)
      assert_not product.product_photo.attached?
      assert_not product.lifestyle_photo.attached?

      rows = parse(ProductFeed.new(Product.where(id: product.id)).to_csv)

      assert_empty rows
    end

    test "a tiered product is priced at its single-pack tier" do
      product = products(:one)
      attach_product_photo(product)
      product.update!(pricing_tiers: [
        { "quantity" => 1, "price" => "26.00" },
        { "quantity" => 3, "price" => "24.00" }
      ])

      row = parse(ProductFeed.new(Product.where(id: product.id)).to_csv).first

      assert_equal "26.00 GBP", row["price"]
    end

    test "carries the GTIN when the product has one" do
      product = products(:one)
      attach_product_photo(product)
      product.update!(gtin: "1234567890123")

      row = parse(ProductFeed.new(Product.where(id: product.id)).to_csv).first

      assert_equal "1234567890123", row["gtin"]
      assert_equal product.sku, row["mpn"]
    end

    test "classifies the product by category path and Google taxonomy id" do
      product = products(:one)
      attach_product_photo(product)
      product.update!(category: categories(:child_hot_cups))

      row = parse(ProductFeed.new(Product.where(id: product.id)).to_csv).first

      assert_equal "Cups & Drinks > Hot Cups", row["product_category"]
      assert_equal "5099", row["google_product_category"]
    end

    test "groups family siblings under one item group with their variant attributes" do
      white = products(:napkin_small_white)
      natural = products(:napkin_small_natural)
      [ white, natural ].each { |product| attach_product_photo(product) }
      white.update!(colour: "White", material: "Paper", pac_size: 100)
      natural.update!(colour: "Natural", material: "Paper", pac_size: 100)

      rows = parse(ProductFeed.new(Product.where(id: [ white.id, natural.id ])).to_csv)
      by_sku = rows.index_by { |row| row["id"] }

      assert_equal by_sku[white.sku]["item_group_id"], by_sku[natural.sku]["item_group_id"]
      assert by_sku[white.sku]["item_group_id"].present?
      assert_equal white.product_family.name, by_sku[white.sku]["item_group_title"]
      assert_equal "White", by_sku[white.sku]["color"]
      assert_equal "Natural", by_sku[natural.sku]["color"]
      assert_equal "Paper", by_sku[white.sku]["material"]
      assert_equal "Pack of 100", by_sku[white.sku]["size"]
    end

    test "ships to GB at the standard cost, free over the threshold, once per order" do
      product = products(:one)
      attach_product_photo(product)

      row = parse(ProductFeed.new(Product.where(id: product.id)).to_csv).first

      assert_equal "GB:ALL:Standard:1-1:6.99 GBP", row["shipping"]
      assert_equal "GB:ALL:Standard:100.00 GBP", row["free_shipping_threshold"]
      assert_equal "per_order", row["shipping_cost_basis"]
      assert_equal "exclusive", row["shipping_tax_behavior"]
    end

    test "description is plain text capped at 5000 characters" do
      product = products(:one)
      attach_product_photo(product)
      product.update!(description_detailed: "<p>Sturdy <strong>cups</strong>.</p>" + ("x" * 6000))

      row = parse(ProductFeed.new(Product.where(id: product.id)).to_csv).first

      assert row["description"].start_with?("Sturdy cups.")
      assert_no_match(/<[a-z]+>/, row["description"])
      assert_equal 5000, row["description"].length
    end

    test "carries the lifestyle photo as an additional image and the ad labels" do
      product = products(:one)
      attach_product_photo(product)
      product.lifestyle_photo.attach(
        io: file_fixture("test_image.jpg").open, filename: "lifestyle.jpg", content_type: "image/jpeg"
      )
      product.update!(best_seller: true)

      row = parse(ProductFeed.new(Product.where(id: product.id)).to_csv).first

      assert_match %r{\Ahttps://example.com/.+}, row["additional_image_link"]
      assert_not_equal row["image_link"], row["additional_image_link"]
      assert_equal "yes", row["custom_label_1"]
      assert_equal product.category.slug, row["custom_label_3"]
    end

    private

    def parse(csv)
      CSV.parse(csv, headers: true)
    end

    def attach_product_photo(product)
      return if product.product_photo.attached?

      product.product_photo.attach(
        io: file_fixture("test_image.jpg").open,
        filename: "product.jpg",
        content_type: "image/jpeg"
      )
    end
  end
end
