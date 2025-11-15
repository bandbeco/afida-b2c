require "application_system_test_case"

class CategoryDescriptionsTest < ApplicationSystemTestCase
  test "category page displays short descriptions on product cards" do
    category = categories(:one)
    product = products(:one)
    product.update!(category: category)
    product.update_columns(
      description_short: "Short category product description",
      description_standard: "Standard description",
      description_detailed: "Detailed description"
    )

    visit category_path(category)

    # Should see the product name (category cards use h2 in _product.html.erb partial)
    assert_selector "h2", text: product.name

    # Should see the short description on the card
    assert_text "Short category product description"
  end

  test "category page shows fallback when short description missing" do
    category = categories(:one)
    product = products(:one)
    product.update!(category: category)
    product.update_columns(
      description_short: nil,
      description_standard: nil,
      description_detailed: "This is a detailed description fallback with many words to test the truncation logic properly and completely"
    )

    visit category_path(category)

    # Should see truncated detailed description with ellipsis
    assert_text /This is a detailed description fallback.*\.\.\./
  end
end
