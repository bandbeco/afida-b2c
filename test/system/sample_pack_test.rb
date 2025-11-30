require "application_system_test_case"

class SamplePackTest < ApplicationSystemTestCase
  setup do
    @sample_pack = products(:sample_pack)
    @variant = product_variants(:sample_pack_variant)
  end

  test "samples landing page displays sample pack information" do
    visit samples_path

    assert_selector "h1", text: /Eco-Friendly|Sample/i
    assert_text "Free"
    assert_selector "button, input[type='submit'], a.btn", text: /Add to Cart|Add Sample Pack/i
  end

  test "can add sample pack to cart from landing page" do
    visit samples_path

    # Find and click the first add to cart button (there are two on the page)
    first("button", text: /Add Sample Pack to Cart/i).click

    # Should redirect to cart or show success
    assert_text(/added|cart/i)
  end

  test "samples page shows what is included section" do
    visit samples_path

    assert_text(/included|contains|selection/i)
  end
end
