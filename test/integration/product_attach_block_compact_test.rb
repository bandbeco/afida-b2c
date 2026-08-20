require "test_helper"

# The attach block was the tallest thing on the page: four full-width rows
# pushed Add to Cart nearly two viewports down on desktop. These lock in the
# compact card layout that keeps the whole buy box within reach.
class ProductAttachBlockCompactTest < ActionDispatch::IntegrationTest
  setup do
    @container = products(:branded_cup_8oz)
    @lid = products(:flat_lid_8oz)
  end

  test "companions are laid out as a multi-column grid, not a single stack" do
    get product_path(@container)

    assert_select "[data-test='attach-grid'].grid"
  end

  # The card carries only what a buyer needs to choose: what it is, whether it
  # fits, and the rate they compare on. Pack price and quantity are detail for
  # a lid they have actually picked.
  test "an unticked card shows the name, fit cue and unit price" do
    get product_path(@container)

    assert_select "[data-test='attach-row']" do |cards|
      card = cards.first
      assert_match @lid.generated_title, card.text
      assert_match(/fits this/i, card.text)
      assert_match(/1\.5p \/ unit/, card.text)
    end
  end

  # Kept out of the card face but present in the DOM, revealed when the card is
  # ticked, so choosing a lid never costs a page load or a modal round trip.
  test "pack price and quantity ride along in a details region" do
    get product_path(@container)

    assert_select "[data-test='attach-row-details']" do
      assert_select "select[name=?]", "companions[0][quantity]"
    end
    assert_select "[data-test='attach-row-details']", text: /pack of 1,000/
  end

  test "the details region starts hidden so unticked cards stay compact" do
    get product_path(@container)

    assert_select "[data-test='attach-row-details'].hidden"
  end

  # The checkbox is the only thing marking a card as selectable, and the brand
  # mint on white measures 1.45:1, under the 3:1 WCAG asks of a control. The
  # unchecked box needs a neutral border a buyer can actually see; the mint
  # belongs to the checked state, where it reads against the fill.
  test "the unchecked checkbox uses a visible neutral border, not the brand mint" do
    get product_path(@container)

    assert_select "[data-test='attach-row'] input[type=checkbox]" do |boxes|
      assert_no_match(/checkbox-primary/, boxes.first["class"],
                      "checkbox-primary renders the unchecked border in brand mint")
      assert_match(/border-base-content/, boxes.first["class"])
    end
  end

  test "the companion checkbox still submits from the compact card" do
    get product_path(@container)

    assert_select "form#add-to-cart-form [data-test='attach-row'] input[type=checkbox][name=?]",
                  "companions[0][sku]"
  end
end
