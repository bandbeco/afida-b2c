require "application_system_test_case"

class ProductDescriptionsTest < ApplicationSystemTestCase
  test "product page displays standard description above fold" do
    product = products(:one)
    product.update_columns(
      description_short: "Short text",
      description_standard: "Standard intro description for above the fold",
      description_detailed: "Detailed description"
    )

    visit product_path(product)

    # Should see standard description prominently displayed
    assert_text "Standard intro description for above the fold"
  end

  test "product page displays detailed description below fold" do
    product = products(:one)
    product.update_columns(
      description_short: "Short text",
      description_standard: "Standard text",
      description_detailed: "This is the comprehensive detailed description with all the product information and benefits for customers to read"
    )

    visit product_path(product)

    # Should see detailed description in product details section
    assert_text "This is the comprehensive detailed description"
    # Should have About heading with product name
    assert_selector "h2", text: "About Our #{product.name}"
  end

  test "product page content flows continuously without tabs" do
    product = products(:one)
    product.update_columns(
      description_standard: "Standard description",
      description_detailed: "Detailed description"
    )

    visit product_path(product)

    # Should NOT have tab elements (continuous scroll)
    assert_no_selector ".tabs"
    assert_no_selector ".tab"
    assert_no_selector "[role='tablist']"
  end

  test "product page shows fallback descriptions when fields missing" do
    product = products(:one)
    product.update_columns(
      description_short: nil,
      description_standard: nil,
      description_detailed: "This is the only description available so it will be used as a fallback for both standard and detailed sections"
    )

    visit product_path(product)

    # Should see truncated version of detailed for standard intro
    assert_text /This is the only description available so it will be used as a fallback for/
  end
end
