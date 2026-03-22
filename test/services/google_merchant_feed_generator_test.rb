require "test_helper"

class GoogleMerchantFeedGeneratorTest < ActiveSupport::TestCase
  def setup
    Rails.application.routes.default_url_options[:host] = "example.com"
  end

  private

  def attach_product_photo(product)
    return if product.product_photo.attached?

    product.product_photo.attach(
      io: file_fixture("test_image.jpg").open,
      filename: "product.jpg",
      content_type: "image/jpeg"
    )
  end

  public

  test "generates optimized product title" do
    product = products(:one)
    attach_product_photo(product)

    generator = GoogleMerchantFeedGenerator.new(Product.where(id: product.id))
    xml = Nokogiri::XML(generator.generate_xml)

    title = xml.at_xpath("//item/g:title", "g" => "http://base.google.com/ns/1.0").text

    # Should include: Brand + Product Type + Size + Material + Feature + Pack Size
    assert_includes title, "Afida"
    assert_includes title, product.generated_title
    assert title.length <= 150, "Title should be 150 chars or less, got #{title.length}"
  end

  test "includes custom labels in feed" do
    product = products(:one)
    attach_product_photo(product)
    product.update!(
      best_seller: true,
      b2b_priority: "high"
    )

    generator = GoogleMerchantFeedGenerator.new(Product.where(id: product.id))
    xml = Nokogiri::XML(generator.generate_xml)

    # custom_label_0 is no longer used (profit_margin removed)
    assert_equal "yes", xml.at_xpath("//item/g:custom_label_1", "g" => "http://base.google.com/ns/1.0").text
    assert_equal product.category.slug, xml.at_xpath("//item/g:custom_label_3", "g" => "http://base.google.com/ns/1.0").text
  end

  test "includes GTIN when present" do
    product = products(:one)
    attach_product_photo(product)
    product.update!(gtin: "1234567890123")

    generator = GoogleMerchantFeedGenerator.new(Product.where(id: product.id))
    xml = Nokogiri::XML(generator.generate_xml)

    gtin = xml.at_xpath("//item/g:gtin", "g" => "http://base.google.com/ns/1.0")
    assert_equal "1234567890123", gtin.text
  end

  test "product_type includes parent and subcategory" do
    product = products(:hot_cup_in_subcategory)
    attach_product_photo(product)

    generator = GoogleMerchantFeedGenerator.new(Product.where(id: product.id))
    xml = Nokogiri::XML(generator.generate_xml)

    product_type = xml.at_xpath("//item/g:product_type", "g" => "http://base.google.com/ns/1.0").text
    assert_equal "#{product.category.parent.name} > #{product.category.name}", product_type
  end

  test "brand uses product brand when present" do
    product = products(:vegware_hot_cup)
    attach_product_photo(product)

    generator = GoogleMerchantFeedGenerator.new(Product.where(id: product.id))
    xml = Nokogiri::XML(generator.generate_xml)

    brand = xml.at_xpath("//item/g:brand", "g" => "http://base.google.com/ns/1.0").text
    assert_equal "Vegware", brand
  end

  test "brand defaults to Afida when product has no brand" do
    product = products(:one)
    attach_product_photo(product)

    generator = GoogleMerchantFeedGenerator.new(Product.where(id: product.id))
    xml = Nokogiri::XML(generator.generate_xml)

    brand = xml.at_xpath("//item/g:brand", "g" => "http://base.google.com/ns/1.0").text
    assert_equal "Afida", brand
  end

  test "product_image_url converts webp to jpeg" do
    product = products(:one)
    product.product_photo.attach(
      io: file_fixture("test_image.webp").open,
      filename: "product.webp",
      content_type: "image/webp"
    )

    generator = GoogleMerchantFeedGenerator.new(Product.where(id: product.id))
    xml = Nokogiri::XML(generator.generate_xml)
    image_link = xml.at_xpath("//item/g:image_link", "g" => "http://base.google.com/ns/1.0").text

    assert_includes image_link, "representations", "WebP images should use variant representation for format conversion"
  end

  test "product_image_url passes through jpeg images without conversion" do
    product = products(:one)
    product.product_photo.attach(
      io: file_fixture("test_image.jpg").open,
      filename: "product.jpg",
      content_type: "image/jpeg"
    )

    generator = GoogleMerchantFeedGenerator.new(Product.where(id: product.id))
    xml = Nokogiri::XML(generator.generate_xml)
    image_link = xml.at_xpath("//item/g:image_link", "g" => "http://base.google.com/ns/1.0").text

    assert_not_empty image_link
    assert_includes image_link, "blobs", "JPEG images should use direct blob URL"
  end

  test "excludes products without any images from feed" do
    product = products(:one)
    # product has no attached photos
    assert_not product.product_photo.attached?

    generator = GoogleMerchantFeedGenerator.new(Product.where(id: product.id))
    xml = Nokogiri::XML(generator.generate_xml)
    items = xml.xpath("//item")

    assert_equal 0, items.count, "Products without images should be excluded from feed"
  end

  test "includes google_product_category for products with categories" do
    product = products(:hot_cup_in_subcategory)
    attach_product_photo(product)

    generator = GoogleMerchantFeedGenerator.new(Product.where(id: product.id))
    xml = Nokogiri::XML(generator.generate_xml)

    google_category = xml.at_xpath("//item/g:google_product_category", "g" => "http://base.google.com/ns/1.0")
    assert_not_nil google_category, "Feed should include google_product_category"
    assert_not_empty google_category.text
  end

  test "google_product_category maps known category slugs to Google taxonomy IDs" do
    product = products(:hot_cup_in_subcategory)
    attach_product_photo(product)

    generator = GoogleMerchantFeedGenerator.new(Product.where(id: product.id))
    xml = Nokogiri::XML(generator.generate_xml)

    google_category = xml.at_xpath("//item/g:google_product_category", "g" => "http://base.google.com/ns/1.0")
    # Hot Cups should map to a Google taxonomy category
    assert_match(/\d+/, google_category.text, "Google product category should be a taxonomy ID")
  end

  test "optimized description has first 160 chars with key info" do
    product = products(:one)
    attach_product_photo(product)
    # Remove existing descriptions to test generated one
    product.update!(description_short: nil, description_standard: nil, description_detailed: nil)

    generator = GoogleMerchantFeedGenerator.new(Product.where(id: product.id))
    xml = Nokogiri::XML(generator.generate_xml)

    description = xml.at_xpath("//item/g:description", "g" => "http://base.google.com/ns/1.0").text
    first_160 = description[0..159]

    # First 160 chars should include brand, product type, use case, material, eco credential
    assert_includes first_160.downcase, "afida"
    assert first_160.length <= 160
  end
end
