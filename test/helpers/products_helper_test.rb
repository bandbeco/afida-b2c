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
end
