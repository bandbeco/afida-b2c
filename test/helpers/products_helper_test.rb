# frozen_string_literal: true

require "test_helper"

class ProductsHelperTest < ActionView::TestCase
  # render_product_description tests

  test "render_product_description returns empty string for nil" do
    result = render_product_description(nil)

    assert_equal "", result
  end

  test "render_product_description returns empty string for blank" do
    result = render_product_description("")

    assert_equal "", result
  end

  test "render_product_description renders plain text in paragraph" do
    result = render_product_description("Simple description text.")

    assert_match %r{<p>Simple description text\.</p>}, result
  end

  test "render_product_description converts markdown links to HTML" do
    text = "Check out our [bamboo straws](/product/straws-6-x-200mm-bamboo-pulp) for drinks."

    result = render_product_description(text)

    assert_match %r{<a href="/product/straws-6-x-200mm-bamboo-pulp".*>bamboo straws</a>}, result
  end

  test "render_product_description adds link-inline class to links" do
    text = "See our [products](/shop) today."

    result = render_product_description(text)

    assert_match /class="link-inline"/, result
  end

  test "render_product_description handles multiple links" do
    text = "Try [short straws](/product/short) or [long straws](/product/long)."

    result = render_product_description(text)

    assert_match %r{<a href="/product/short" class="link-inline">short straws</a>}, result
    assert_match %r{<a href="/product/long" class="link-inline">long straws</a>}, result
  end

  test "render_product_description handles external URLs" do
    text = "Learn more at [our blog](https://blog.example.com/article)."

    result = render_product_description(text)

    assert_match %r{<a href="https://blog.example.com/article" class="link-inline">our blog</a>}, result
  end

  test "render_product_description preserves text without markdown" do
    text = "No links here, just plain description with numbers 123 and symbols & stuff."

    result = render_product_description(text)

    assert_match /No links here/, result
    assert_match /numbers 123/, result
    assert_match /symbols &amp; stuff/, result # HTML escaped
  end

  test "render_product_description handles underscores in text without emphasis" do
    text = "Product SKU_123_ABC is available."

    result = render_product_description(text)

    assert_match /SKU_123_ABC/, result
    refute_match /<em>/, result # no_intra_emphasis option
  end

  test "render_product_description autolinks bare URLs" do
    text = "Visit https://example.com for more info."

    result = render_product_description(text)

    assert_match %r{<a href="https://example.com".*>https://example.com</a>}, result
  end

  test "render_product_description returns html_safe string" do
    result = render_product_description("Test text.")

    assert result.html_safe?
  end

  # search_display_title tests

  test "search_display_title shows size - brand material family_name" do
    product = products(:one)
    product.update_columns(brand: "Vegware", size: "10 x 200mm", material: "Bamboo Pulp", name: "Straws")

    result = search_display_title(product)

    assert_equal "10 x 200mm - Vegware Bamboo Pulp Straws", result
  end

  test "search_display_title without brand shows size - material name" do
    product = products(:one)
    product.update_columns(brand: nil, size: "8oz", material: "Paper", name: "Hot Cups")

    result = search_display_title(product)

    assert_equal "8oz - Paper Hot Cups", result
  end

  test "search_display_title without size shows brand material name" do
    product = products(:one)
    product.update_columns(brand: "Vegware", size: nil, material: "Bamboo Pulp", name: "Straws")

    result = search_display_title(product)

    assert_equal "Vegware Bamboo Pulp Straws", result
  end

  test "search_display_title uses product_family name when available" do
    family = ProductFamily.create!(name: "Straws", slug: "straws")
    product = products(:one)
    product.update!(product_family: family)
    product.update_columns(brand: "Vegware", size: "10 x 200mm", material: "Bamboo Pulp", name: "Vegware 10 x 200mm Bamboo Pulp Straws")

    result = search_display_title(product)

    assert_equal "10 x 200mm - Vegware Bamboo Pulp Straws", result
  end

  test "search_display_title falls back to generated_title when all blank" do
    product = products(:one)
    product.update_columns(brand: nil, size: nil, material: nil, name: "")

    result = search_display_title(product)

    assert_equal product.generated_title, result
  end

  # search_display_subtitle tests

  test "search_display_subtitle shows pack size when present" do
    product = products(:one)
    product.update_columns(pac_size: 3600, material: "Bamboo Pulp", name: "Straws")

    result = search_display_subtitle(product)

    assert_equal "Pack of 3,600", result
  end

  test "search_display_subtitle returns nil when no pack size" do
    product = products(:one)
    product.update_columns(pac_size: nil, material: "Paper", name: "Cups")

    result = search_display_subtitle(product)

    assert_nil result
  end

  test "search_display_subtitle returns nil when pack size is 1" do
    product = products(:one)
    product.update_columns(pac_size: 1, material: "Paper", name: "Cups")

    result = search_display_subtitle(product)

    assert_nil result
  end
end
