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

  # pricing_tier_breakdown tests

  test "pricing_tier_breakdown returns empty array for blank tiers" do
    assert_equal [], pricing_tier_breakdown(nil)
    assert_equal [], pricing_tier_breakdown([])
  end

  test "pricing_tier_breakdown computes per-unit price from price and quantity" do
    tiers = [
      { "quantity" => 1_000, "price" => "6.69" },
      { "quantity" => 10_000, "price" => "19.61" }
    ]

    result = pricing_tier_breakdown(tiers)

    assert_in_delta 0.00669, result[0][:price_per_unit], 0.000001
    assert_in_delta 0.001961, result[1][:price_per_unit], 0.000001
  end

  test "pricing_tier_breakdown sets nil savings for the first (cheapest-per-unit baseline) tier" do
    tiers = [
      { "quantity" => 1_000, "price" => "6.69" },
      { "quantity" => 10_000, "price" => "19.61" }
    ]

    result = pricing_tier_breakdown(tiers)

    assert_nil result[0][:savings_percent]
  end

  test "pricing_tier_breakdown computes savings percent relative to first tier per-unit price" do
    tiers = [
      { "quantity" => 1_000, "price" => "6.69" },
      { "quantity" => 10_000, "price" => "19.61" }
    ]

    result = pricing_tier_breakdown(tiers)

    # base per-unit 0.00669, tier2 per-unit 0.001961 -> ~71% saving
    assert_equal 71, result[1][:savings_percent]
  end

  test "pricing_tier_breakdown omits savings when there is no positive saving" do
    tiers = [
      { "quantity" => 100, "price" => "10.00" },
      { "quantity" => 200, "price" => "20.00" } # same per-unit price
    ]

    result = pricing_tier_breakdown(tiers)

    assert_nil result[1][:savings_percent]
  end

  test "pricing_tier_breakdown preserves original quantity and price" do
    tiers = [ { "quantity" => 1_000, "price" => "6.69" } ]

    result = pricing_tier_breakdown(tiers)

    assert_equal 1_000, result[0][:quantity]
    assert_equal BigDecimal("6.69"), result[0][:price]
  end

  # card_price_line tests

  test "card_price_line quotes the best tier unit price with the minimum quantity" do
    product = products(:one)
    product.update!(pac_size: 1000, pricing_tiers: [
      { "quantity" => 1000, "price" => "29.65" },
      { "quantity" => 25000, "price" => "519.00" }
    ])

    assert_equal "From 2.1p/unit · min 1,000", card_price_line(product)
  end

  test "card_price_line shows unit price and pack size for flat-priced products" do
    product = products(:one)
    product.update!(pricing_tiers: nil, price: 26.60, pac_size: 1000)

    assert_equal "2.7p/unit · pack of 1,000", card_price_line(product)
  end

  test "card_price_line uses pounds for unit prices of a pound or more" do
    product = products(:one)
    product.update!(pricing_tiers: nil, price: 620.00, pac_size: 500)

    assert_equal "£1.24/unit · pack of 500", card_price_line(product)
  end

  test "card_price_line drops the pence decimal when it is whole" do
    product = products(:one)
    product.update!(pricing_tiers: nil, price: 30.00, pac_size: 1000)

    assert_equal "3p/unit · pack of 1,000", card_price_line(product)
  end

  test "card_price_line falls back to the plain price without a pack size" do
    product = products(:one)
    product.update!(pricing_tiers: nil, price: 41.31, pac_size: nil)

    assert_equal "£41.31", card_price_line(product)
  end

  # search_price_line tests (issue #248)

  test "search_price_line pairs the pack price with a per-unit rate" do
    product = products(:one)
    product.update!(pricing_tiers: nil, price: 86.15, pac_size: 1000)
    row = SearchResultRow.new([ product ])

    assert_equal "£86.15 · 8.6p per unit", search_price_line(row)
  end

  test "search_price_line uses pounds for per-unit rates of a pound or more" do
    product = products(:one)
    product.update!(pricing_tiers: nil, price: 620.00, pac_size: 500)
    row = SearchResultRow.new([ product ])

    assert_equal "£620.00 · £1.24 per unit", search_price_line(row)
  end

  test "search_price_line shows the plain price for a single-unit pack" do
    product = products(:one)
    product.update!(pricing_tiers: nil, price: 9.99, pac_size: 1)
    row = SearchResultRow.new([ product ])

    assert_equal "£9.99", search_price_line(row)
  end

  # search_row_subtitle tests

  test "search_row_subtitle shows the per-product pack subtitle" do
    product = products(:one)
    product.update_columns(pac_size: 3600, material: "Bamboo Pulp", name: "Straws")
    row = SearchResultRow.new([ product ])

    assert_equal "Pack of 3,600", search_row_subtitle(row)
  end

  # branded_price_anchor tests (issue #248)

  test "branded_price_anchor quotes the cheapest per-unit price and the max volume discount" do
    product = products(:branded_template_variant)

    assert_equal "From 18p per unit · save up to 40% in volume",
                 branded_price_anchor(product)
  end

  test "branded_price_anchor drops the discount clause when there is no volume saving" do
    product = products(:branded_template_variant)
    product.branded_product_prices.destroy_all
    product.branded_product_prices.create!(
      size: "8oz", quantity_tier: 1000, price_per_unit: 0.25, case_quantity: 500
    )

    assert_equal "From 25p per unit", branded_price_anchor(product)
  end

  # highlight_search_match tests (issue #250)

  test "highlight_search_match wraps the matched term in a mint-tinted mark" do
    result = highlight_search_match("8oz White Cups", "white")

    assert_match %r{<mark class="[^"]*bg-primary/10[^"]*">White</mark>}, result
  end

  test "highlight_search_match preserves the original casing of the match" do
    result = highlight_search_match("8oz White Cups", "WHITE")

    assert_includes result, ">White</mark>"
  end

  test "highlight_search_match highlights every query word" do
    result = highlight_search_match("8oz White Cups", "white cups")

    assert_includes result, ">White</mark>"
    assert_includes result, ">Cups</mark>"
  end

  test "highlight_search_match escapes HTML in the title" do
    result = highlight_search_match("<script>alert(1)</script> cups", "cups")

    refute_includes result, "<script>"
    assert_includes result, "&lt;script&gt;"
  end

  test "highlight_search_match does not interpret regex metacharacters in the query" do
    result = highlight_search_match("8oz White Cups", "wh.te")

    # A literal "wh.te" must not match "Whit"; the title comes back escaped and
    # unhighlighted rather than treating "." as a wildcard.
    refute_includes result, "<mark"
    assert_includes result, "8oz White Cups"
  end

  test "highlight_search_match returns the escaped title unchanged for a blank query" do
    result = highlight_search_match("8oz White Cups", "")

    refute_includes result, "<mark"
    assert_includes result, "8oz White Cups"
  end

  test "highlight_search_match returns an html_safe string" do
    result = highlight_search_match("8oz White Cups", "white")

    assert_predicate result, :html_safe?
  end
end
