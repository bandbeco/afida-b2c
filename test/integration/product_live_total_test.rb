require "test_helper"

# The Total sits directly above Add to Cart, so it is the last number a buyer
# reads before committing. It has to move when the selection moves: quantity,
# tier, and anything ticked in the attach block.
class ProductLiveTotalTest < ActionDispatch::IntegrationTest
  test "the buy box listens for attach-block selection changes" do
    get product_path(products(:branded_cup_8oz))

    assert_select "[data-action*='attach-companions:changed']"
  end

  test "each attach row carries the price the total needs to add" do
    get product_path(products(:branded_cup_8oz))

    assert_select "[data-test='attach-row'] input[data-companion-price=?]",
                  products(:flat_lid_8oz).price.to_f.to_s
  end

  test "a tiered product wires the same selection changes into its total" do
    get product_path(products(:single_wall_8oz_white))

    assert_select "[data-action*='attach-companions:changed->pricing-tier#companionsChanged']"
  end
end
