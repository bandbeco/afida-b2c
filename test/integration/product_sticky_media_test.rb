require "test_helper"

# On wide screens the media column is much shorter than the buy column, so it
# scrolls away and leaves dead space beside the decision the buyer is making.
# Pinning it keeps the product in view for the whole buy box.
class ProductStickyMediaTest < ActionDispatch::IntegrationTest
  test "the media column is pinned on wide screens" do
    get product_path(products(:branded_cup_8oz))

    assert_select "[data-test='product-media'].lg\\:sticky"
  end

  # Phones stack the columns, so a pinned image would eat the viewport the buy
  # box needs. The pin is a wide-screen affordance only.
  test "the media column is not pinned on small screens" do
    get product_path(products(:branded_cup_8oz))

    assert_select "[data-test='product-media']" do |columns|
      assert_no_match(/(^|\s)sticky(\s|$)/, columns.first["class"],
                      "sticky must be qualified by a breakpoint, never unconditional")
    end
  end
end
