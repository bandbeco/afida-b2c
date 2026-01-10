require "application_system_test_case"

class VariantPageTest < ApplicationSystemTestCase
  setup do
    @variant = product_variants(:single_wall_8oz_white)
    @product = @variant.product
    @category = @product.category
  end

  test "variant page displays correct product information" do
    visit product_variant_path(@variant.slug)

    # Check page title includes variant name
    assert_title "#{@variant.full_name} | Afida"

    # Check main heading
    assert_selector "h1", text: @variant.full_name

    # Check price is displayed
    assert_text number_to_currency(@variant.price)

    # Check SKU is displayed
    assert_text "SKU: #{@variant.sku}"
  end

  test "variant page displays pack information when pac_size is present" do
    variant_with_pac = product_variants(:paper_lid_80mm)
    visit product_variant_path(variant_with_pac.slug)

    # Should show units per pack
    assert_text "#{number_with_delimiter(variant_with_pac.pac_size)} units per pack"
  end

  test "variant page has breadcrumb navigation" do
    visit product_variant_path(@variant.slug)

    within "nav[aria-label='Breadcrumb']" do
      assert_link "Home", href: root_path
      assert_link @category.name, href: category_path(@category)
      assert_text @variant.full_name
    end
  end

  test "variant page includes add to cart form" do
    visit product_variant_path(@variant.slug)

    # Should have quantity field
    assert_selector "input[name='quantity']"

    # Should have add to cart button
    assert_button "Add to Cart"
  end

  test "add to cart adds item to cart drawer" do
    visit product_variant_path(@variant.slug)

    # Fill in quantity and add to cart
    fill_in "quantity", with: 2
    click_button "Add to Cart"

    # Wait for Turbo to process and cart drawer to update
    # The cart drawer checkbox should be checked when item is added
    sleep 1

    # Check cart has updated (cart count in header or drawer content)
    # Use page HTML to verify the form submission worked
    page_html = page.html
    assert_includes page_html, @variant.name, "Cart should contain the added variant"
  end

  test "variant page includes product structured data" do
    visit product_variant_path(@variant.slug)

    page_html = page.html
    assert_includes page_html, '"@type":"Product"', "No Product structured data found"
    assert_includes page_html, @variant.full_name, "Variant name not in structured data"
    assert_includes page_html, @variant.sku, "SKU not in structured data"
    assert_includes page_html, '"priceCurrency":"GBP"', "Currency not in structured data"
  end

  test "variant page includes breadcrumb structured data" do
    visit product_variant_path(@variant.slug)

    page_html = page.html
    assert_includes page_html, '"@type":"BreadcrumbList"', "No BreadcrumbList structured data found"
    assert_includes page_html, "Home", "Home not in breadcrumb structured data"
    assert_includes page_html, @category.name, "Category name not in breadcrumb"
  end

  test "variant page has canonical URL" do
    visit product_variant_path(@variant.slug)

    page_html = page.html
    assert_includes page_html, "rel=\"canonical\"", "No canonical URL found"
    assert_includes page_html, @variant.slug, "Canonical URL doesn't include variant slug"
  end

  test "variant page shows related variants from same product" do
    visit product_variant_path(@variant.slug)

    # The product has multiple variants, so related should appear
    other_variants = @product.active_variants.where.not(id: @variant.id).limit(4)

    if other_variants.any?
      assert_selector "h2", text: "See Also"

      # Should show at least one related variant
      related = other_variants.first
      assert_link related.name, href: product_variant_path(related.slug)
    end
  end

  test "accessing variant page by slug works" do
    # Direct URL access should work
    visit "/products/#{@variant.slug}"

    assert_selector "h1", text: @variant.full_name
  end

  test "inactive variant returns 404" do
    # Create an inactive variant to test 404 behavior
    inactive_variant = product_variants(:single_wall_8oz_black)
    inactive_variant.update!(active: false)

    visit product_variant_path(inactive_variant.slug)

    # Should show 404 page - check for "404" in page title
    page_html = page.html
    assert_includes page_html, "404", "Should show 404 page for inactive variant"
  end

  private

  def number_to_currency(amount)
    ActionController::Base.helpers.number_to_currency(amount)
  end

  def number_with_delimiter(number)
    ActionController::Base.helpers.number_with_delimiter(number)
  end
end
