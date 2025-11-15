require "application_system_test_case"

class ShopDescriptionsTest < ApplicationSystemTestCase
  test "shop page displays short descriptions on product cards" do
    # Set up a product with all three descriptions
    product = products(:one)
    product.update_columns(
      description_short: "Brief product summary here",
      description_standard: "Standard description text",
      description_detailed: "Detailed description text"
    )

    visit shop_path

    # Should see the product name
    assert_selector "h3", text: product.name

    # Should see the short description on the card
    assert_text "Brief product summary here"
  end

  test "shop page shows fallback description when short description missing" do
    # Product with only standard description
    product = products(:one)
    product.update_columns(
      description_short: nil,
      description_standard: "This is a fallback standard description with enough words to test truncation behavior properly when used",
      description_detailed: nil
    )

    visit shop_path

    # Should see truncated standard description with ellipsis
    assert_text /This is a fallback standard description.*\.\.\./
  end
end
