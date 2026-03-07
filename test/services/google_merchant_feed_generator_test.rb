require "test_helper"

class GoogleMerchantFeedGeneratorTest < ActiveSupport::TestCase
  def setup
    Rails.application.routes.default_url_options[:host] = "example.com"
  end

  test "generates optimized product title" do
    product = products(:one)
    variant = products(:one)

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
    product.update!(gtin: "1234567890123")

    generator = GoogleMerchantFeedGenerator.new(Product.where(id: product.id))
    xml = Nokogiri::XML(generator.generate_xml)

    gtin = xml.at_xpath("//item/g:gtin", "g" => "http://base.google.com/ns/1.0")
    assert_equal "1234567890123", gtin.text
  end

  test "product_type includes parent and subcategory" do
    product = products(:hot_cup_in_subcategory)

    generator = GoogleMerchantFeedGenerator.new(Product.where(id: product.id))
    xml = Nokogiri::XML(generator.generate_xml)

    product_type = xml.at_xpath("//item/g:product_type", "g" => "http://base.google.com/ns/1.0").text
    assert_equal "#{product.category.parent.name} > #{product.category.name}", product_type
  end

  test "brand uses product brand when present" do
    product = products(:vegware_hot_cup)

    generator = GoogleMerchantFeedGenerator.new(Product.where(id: product.id))
    xml = Nokogiri::XML(generator.generate_xml)

    brand = xml.at_xpath("//item/g:brand", "g" => "http://base.google.com/ns/1.0").text
    assert_equal "Vegware", brand
  end

  test "brand defaults to Afida when product has no brand" do
    product = products(:one)

    generator = GoogleMerchantFeedGenerator.new(Product.where(id: product.id))
    xml = Nokogiri::XML(generator.generate_xml)

    brand = xml.at_xpath("//item/g:brand", "g" => "http://base.google.com/ns/1.0").text
    assert_equal "Afida", brand
  end

  test "optimized description has first 160 chars with key info" do
    product = products(:one)
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
