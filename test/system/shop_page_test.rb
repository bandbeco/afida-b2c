require "application_system_test_case"

class ShopPageTest < ApplicationSystemTestCase
  test "shop page displays variant cards" do
    visit shop_path

    # Should show variant cards in grid
    assert_selector ".variant-card"

    # Should show multiple variants
    variant = ProductVariant.active.first
    assert_text variant.full_name
  end

  test "clicking variant card navigates to variant page" do
    variant = product_variants(:single_wall_8oz_white)
    visit shop_path

    # Find and click the variant card link
    within "[data-variant-id='#{variant.id}']" do
      click_link variant.full_name
    end

    # Should navigate to variant page
    assert_current_path product_variant_path(variant.slug)
    assert_selector "h1", text: variant.full_name
  end

  test "shop page shows variant prices" do
    visit shop_path

    variant = product_variants(:single_wall_8oz_white)

    within "[data-variant-id='#{variant.id}']" do
      # Should show price
      assert_text number_to_currency(variant.price)
    end
  end

  test "shop page displays add to cart button for in-stock variants" do
    variant = product_variants(:single_wall_8oz_white)
    visit shop_path

    within "[data-variant-id='#{variant.id}']" do
      assert_button "Add to Cart"
    end
  end

  test "shop page displays out of stock for unavailable variants" do
    # Find out of stock variant
    out_of_stock_variant = product_variants(:sip_lid_8oz_variant)
    assert_equal 0, out_of_stock_variant.stock_quantity

    visit shop_path

    within "[data-variant-id='#{out_of_stock_variant.id}']" do
      # Use case-insensitive match since DaisyUI applies text-transform: uppercase
      assert_selector ".btn-disabled", text: /out of stock/i
    end
  end

  test "category page displays only variants from that category" do
    category = categories(:hot_cups_extras)
    visit category_path(category)

    # Should show variants from this category
    variant_in_category = product_variants(:paper_lid_80mm)
    assert_text variant_in_category.full_name

    # Should not show variants from other categories
    variant_other_category = product_variants(:napkin_small_white)
    assert_no_text variant_other_category.full_name
  end

  test "category page clicking variant card navigates to variant page" do
    category = categories(:hot_cups_extras)
    variant = product_variants(:paper_lid_80mm)

    visit category_path(category)

    within "[data-variant-id='#{variant.id}']" do
      click_link variant.full_name
    end

    assert_current_path product_variant_path(variant.slug)
    assert_selector "h1", text: variant.full_name
  end

  private

  def number_to_currency(amount)
    ActionController::Base.helpers.number_to_currency(amount)
  end
end
