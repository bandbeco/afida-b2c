require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @variant = products(:single_wall_8oz_white)
  end

  test "index returns success" do
    get search_url, params: { q: "8oz" }
    assert_response :success
  end

  test "index returns empty results for short query" do
    get search_url, params: { q: "a" }
    assert_response :success
    assert_select ".product-card", count: 0
  end

  test "index returns empty results for blank query" do
    get search_url, params: { q: "" }
    assert_response :success
    assert_select ".product-card", count: 0
  end

  test "index limits results to 5" do
    # Create enough variants to test limit
    # Using existing fixtures - just verify limit is applied
    get search_url, params: { q: "cup" }
    assert_response :success

    # Count should be <= 5
    assert_select ".product-card", maximum: 5
  end

  test "index finds variants by name" do
    get search_url, params: { q: "8oz" }
    assert_response :success
    assert_select "a[href=?]", product_path(@variant.slug)
  end

  test "index finds variants by sku" do
    get search_url, params: { q: @variant.sku }
    assert_response :success
    assert_select "a[href=?]", product_path(@variant.slug)
  end

  test "header results render generated_title" do
    @variant.update_columns(brand: "Vegware", material: "Paper", size: "8oz", name: "Single Wall Cups")
    expected = @variant.generated_title # "Vegware Paper Single Wall Cups - 8oz"

    get search_url, params: { q: "Vegware" }

    assert_response :success
    # Matched terms are wrapped in <mark> for highlighting (issue #250), so
    # strip the tags before asserting the full title rendered.
    assert_includes unhighlighted(response.body), ERB::Util.html_escape(expected)
  end

  test "modal results render generated_title" do
    @variant.update_columns(brand: "Vegware", material: "Paper", size: "8oz", name: "Single Wall Cups")
    expected = @variant.generated_title # "Vegware Paper Single Wall Cups - 8oz"

    get search_url, params: { q: "Vegware", modal: "true" }

    assert_response :success
    assert_includes unhighlighted(response.body), ERB::Util.html_escape(expected)
  end

  test "header dropdown does not show a raw price for brandable templates" do
    brandable = products(:branded_template_variant)

    get search_url, params: { q: brandable.generated_title.split.first }

    assert_response :success
    # The £0.01 template price must never surface in the dropdown.
    assert_no_match(/£0\.01/, response.body)
  end

  test "header dropdown shows the volume-discount treatment for brandable templates" do
    brandable = products(:branded_template_variant)

    get search_url, params: { q: brandable.generated_title.split.first }

    assert_response :success
    assert_match(/save up to/i, response.body)
  end

  test "brandable rows anchor the price with a from per-unit figure" do
    brandable = products(:branded_template_variant)

    get search_url, params: { q: brandable.generated_title.split.first, modal: "true" }

    assert_response :success
    # Cheapest per-unit across the fixture's branded prices is 18p, max
    # volume saving 40%.
    assert_match(%r{From 18p per unit · save up to 40% in volume}, response.body)
  end

  test "catalog rows show the per-unit price alongside the pack price" do
    loose = products(:one)
    loose.update!(product_family_id: nil, material: "Persol", pricing_tiers: nil,
                  price: 86.15, pac_size: 1000)

    get search_url, params: { q: "Persol", modal: "true" }

    assert_response :success
    assert_match(%r{£86\.15 · 8\.6p per unit}, response.body)
  end

  test "index ranks name matches ahead of attribute-only matches" do
    # Detach from their shared family so ranking is asserted over distinct
    # rows rather than a single collapsed family row (issue #247).
    name_match = products(:single_wall_12oz_white)
    name_match.update!(name: "Zephyr Cup", brand: nil, colour: nil, material: nil, product_family: nil)

    attribute_match = products(:single_wall_8oz_white)
    attribute_match.update!(name: "Saucer", brand: "Zephyr", colour: nil, material: nil, product_family: nil)

    get search_url, params: { q: "zephyr" }

    assert_response :success
    name_pos = response.body.index(product_path(name_match.slug))
    attr_pos = response.body.index(product_path(attribute_match.slug))
    assert name_pos, "expected name match to render"
    assert attr_pos, "expected attribute match to render"
    assert_operator name_pos, :<, attr_pos
  end

  # Family collapsing (issue #247)

  test "modal collapses a multi-member family into a single row" do
    # The single_wall_cups family has several catalog members. Give them a
    # shared searchable term and render the modal.
    family_products = ProductFamily.find_by(slug: "single-wall-cups").products.to_a
    family_products.each { |p| p.update_columns(material: "Zingcup") }

    get search_url, params: { q: "Zingcup", modal: "true" }

    assert_response :success
    # Exactly one row links into the family (via its representative), not one
    # per SKU.
    family_links = family_products.map { |p| product_path(p.slug) }
    rendered = family_links.count { |href| response.body.include?("href=\"#{href}\"") }
    assert_equal 1, rendered, "expected a single collapsed family row"
  end

  test "modal shows the family name and variant count for a collapsed family" do
    family = ProductFamily.find_by(slug: "single-wall-cups")
    family.products.each { |p| p.update_columns(material: "Zingcup") }

    get search_url, params: { q: "Zingcup", modal: "true" }

    assert_response :success
    assert_includes response.body, ERB::Util.html_escape(family.name)
    assert_match(/#{family.products.count}\s+variants/i, response.body)
  end

  test "modal count reflects collapsed rows, not raw SKUs" do
    family = ProductFamily.find_by(slug: "single-wall-cups")
    family.products.each { |p| p.update_columns(material: "Zingcup") }
    raw_count = Product.active.catalog_products.search("Zingcup").count

    get search_url, params: { q: "Zingcup", modal: "true" }

    assert_response :success
    assert_operator raw_count, :>, 1, "fixture should have several SKUs to collapse"
    # The truthful count line must not advertise the raw SKU total.
    assert_no_match(/of #{raw_count} results/, response.body)
    # One collapsed family row means a single result.
    assert_match(/1 result for/, response.body)
  end

  test "modal shows the size range for a collapsed family" do
    family = ProductFamily.find_by(slug: "single-wall-cups")
    sizes = %w[4oz 8oz 12oz 16oz 20oz]
    family.products.each_with_index do |p, i|
      p.update_columns(material: "Zingcup", size: sizes[i % sizes.size])
    end

    get search_url, params: { q: "Zingcup", modal: "true" }

    assert_response :success
    # Smallest to largest size, by numeric value.
    assert_match(/4oz\s*[-–]\s*20oz/, response.body)
  end

  test "modal keeps family-less products as individual rows" do
    loose = products(:one)
    loose.update_columns(product_family_id: nil, material: "Solocue")

    get search_url, params: { q: "Solocue", modal: "true" }

    assert_response :success
    assert_select "a[href=?]", product_path(loose.slug)
  end

  test "modal keeps brandable template rows individual" do
    brandable = products(:branded_template_variant)

    get search_url, params: { q: brandable.generated_title.split.first, modal: "true" }

    assert_response :success
    assert_select "a[href=?]", branded_product_path(brandable.slug)
  end

  test "index is accessible without authentication" do
    get search_url, params: { q: "test" }
    assert_response :success
  end

  test "index returns turbo stream format when requested" do
    get search_url, params: { q: "8oz" }, as: :turbo_stream
    assert_response :success
    assert_match(/turbo-stream/, response.media_type)
  end

  test "index shows view all link when results exist" do
    get search_url, params: { q: "8oz" }
    assert_response :success
    # Should link to shop with search query
    assert_select "a[href=?]", shop_path(q: "8oz")
  end

  test "index handles query with special characters" do
    get search_url, params: { q: "test%20query" }
    assert_response :success
  end

  test "index handles very long query" do
    long_query = "a" * 200
    get search_url, params: { q: long_query }
    assert_response :success
  end

  # Modal mode tests
  test "modal mode returns up to 10 results" do
    get search_url, params: { q: "cup", modal: "true" }
    assert_response :success
    # Modal mode should return more results (up to 10)
    assert_select "a[href*='/products/']", maximum: 10
  end

  test "modal mode returns modal_results partial" do
    get search_url, params: { q: "8oz", modal: "true" }
    assert_response :success
    # Modal results use space-y-2 list layout for stacked rows
    assert_select ".space-y-2"
  end

  test "modal turbo stream updates correct frame" do
    get search_url, params: { q: "8oz", modal: "true" }, as: :turbo_stream
    assert_response :success
    assert_match(/search-modal-results/, response.body)
  end

  test "non-modal turbo stream updates header frame" do
    get search_url, params: { q: "8oz" }, as: :turbo_stream
    assert_response :success
    assert_match(/header-search-results/, response.body)
  end

  # View-all affordance (issue #249)

  test "modal result count line links to the full results page" do
    family = ProductFamily.find_by(slug: "single-wall-cups")
    family.products.each { |p| p.update_columns(material: "Zingcup") }

    get search_url, params: { q: "Zingcup", modal: "true" }

    assert_response :success
    # The "Showing X of Y" / "N results" line is itself a link to /shop?q=,
    # so the full results are reachable without scrolling past every row.
    assert_select "a[href=?]", shop_path(q: "Zingcup"), text: /result/i
  end

  # Keyboard navigation, highlighting, and ARIA (issue #250)

  test "result titles highlight the matched query term" do
    get search_url, params: { q: "8oz", modal: "true" }

    assert_response :success
    assert_select "mark.bg-primary\\/10", text: /8oz/i
  end

  test "modal wraps results in an ARIA listbox with option rows" do
    get search_url, params: { q: "8oz", modal: "true" }

    assert_response :success
    assert_select "[role='listbox']"
    assert_select "[role='option']"
  end

  test "modal result rows carry stable ids for aria-activedescendant" do
    get search_url, params: { q: "8oz", modal: "true" }

    assert_response :success
    assert_select "[role='option'][id^='search-result-']"
  end

  test "modal result count line is an aria-live polite region" do
    get search_url, params: { q: "8oz", modal: "true" }

    assert_response :success
    assert_select "[aria-live='polite']"
  end

  # Empty and zero-result states (issue #251)

  test "falls back to search_extended when the direct search finds nothing" do
    loose = products(:one)
    loose.update!(product_family_id: nil, name: "Plain Widget", sku: "PW-1",
                  brand: nil, colour: nil, material: nil, size: nil)
    loose.category.update!(name: "Zorptastic Supplies")

    # "Zorptastic" matches only the category name, so plain :search misses it
    # but :search_extended finds it.
    get search_url, params: { q: "Zorptastic", modal: "true" }

    assert_response :success
    assert_select "a[href=?]", product_path(loose.slug)
  end

  test "renders the most-searched chips when even the extended search is empty" do
    get search_url, params: { q: "zzzznomatchqueryzzzz", modal: "true" }

    assert_response :success
    # The dead-end copy is replaced by the reusable Most searched chips.
    assert_select "p", text: /Most searched/i
    assert_no_match(/try a different search term/i, response.body)
  end

  test "no-results state still names the query" do
    get search_url, params: { q: "zzzznomatchqueryzzzz", modal: "true" }

    assert_response :success
    assert_match(/zzzznomatchqueryzzzz/, response.body)
  end

  test "search input placeholder models an example query" do
    # The full (non-modal) search page renders the app layout, which mounts the
    # search modal and its input.
    get search_url, params: { q: "8oz" }

    assert_response :success
    assert_select "input[data-search-modal-target='input'][placeholder=?]",
                  "Search cups, boxes, napkins..."
  end

  private

  # Removes the <mark> highlight wrappers so an assertion can match a title as a
  # contiguous substring regardless of which words were highlighted (#250).
  def unhighlighted(html)
    html.gsub(%r{</?mark[^>]*>}, "")
  end
end
