require "test_helper"

# The stepper is one control, not three. The site-wide pill radius applies to
# every .btn, so DaisyUI's join left fully-rounded buttons either side of a
# square field with doubled borders between them.
class ProductQuantityStepperTest < ActionDispatch::IntegrationTest
  test "a flat-priced product's stepper drives the quantity controller" do
    get product_path(products(:flat_lid_8oz))

    assert_select "input#quantity[data-quantity-selector-target='input']"
    assert_select "[data-action='click->quantity-selector#decrement']"
    assert_select "[data-action='click->quantity-selector#increment']"
  end

  test "a tiered product's stepper drives the pricing-tier controller" do
    get product_path(products(:single_wall_8oz_white))

    assert_select "input#quantity[data-pricing-tier-target='input']"
    assert_select "[data-action='click->pricing-tier#decrement']"
    assert_select "[data-action='click->pricing-tier#increment']"
  end

  # The pill radius is what broke the group's shape, so the stepper's buttons
  # must not pick up the global button styling.
  test "the stepper buttons are not pill-radius site buttons" do
    get product_path(products(:flat_lid_8oz))

    assert_select "[data-action='click->quantity-selector#increment']" do |buttons|
      assert_no_match(/\bbtn\b/, buttons.first["class"])
    end
  end

  test "the stepper keeps its accessible labels" do
    get product_path(products(:flat_lid_8oz))

    assert_select "button[aria-label='Increase quantity']"
    assert_select "button[aria-label='Decrease quantity']"
    assert_select "input#quantity[aria-label='Quantity']"
  end
end
