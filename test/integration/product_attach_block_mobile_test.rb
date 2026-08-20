require "test_helper"

# Mobile is the majority of product-page traffic, and the attach block is the
# tallest thing on the page, so it is what a phone buyer actually scrolls
# through. These assert the markup contracts that keep it usable there; the
# geometry itself was verified in a real mobile viewport.
class ProductAttachBlockMobileTest < ActionDispatch::IntegrationTest
  setup do
    @container = products(:branded_cup_8oz)
  end

  # The floating WhatsApp button is fixed to the bottom-right corner and sits
  # above the page. Full-width row controls run underneath it, so a tap meant
  # for a lid quantity hits "chat with us" instead.
  test "attach rows reserve the corner the floating button occupies" do
    get product_path(@container)

    assert_select "[data-test='attach-row']" do
      assert_select "[data-test='attach-row-controls'].max-md\\:pr-20"
    end
  end

  # The buy column is centre-aligned for the title and price. Inherited by the
  # attach rows it centres every name, cue and price, which is why the block
  # reads as a wall of text rather than a list you can run your eye down.
  test "attach rows are left-aligned regardless of the buy column's alignment" do
    get product_path(@container)

    assert_select "[data-test='attach-block'].text-left"
    assert_select "[data-test='attach-row'].text-left"
  end
end
