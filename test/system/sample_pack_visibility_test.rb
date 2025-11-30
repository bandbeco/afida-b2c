require "application_system_test_case"

class SamplePackVisibilityTest < ApplicationSystemTestCase
  setup do
    @sample_pack = products(:sample_pack)
  end

  test "sample pack is not visible on shop page" do
    visit shop_path

    # Sample pack should NOT appear in shop listings
    assert_no_text @sample_pack.name
  end

  test "sample pack is visible on samples landing page" do
    visit samples_path

    # Sample pack content should be visible
    assert_text(/Eco-Friendly|Sample/i)
    assert_text "Free"
  end

  test "sample pack is accessible via direct URL" do
    visit product_path(@sample_pack)

    # Sample pack product page should load
    assert_text @sample_pack.name
    assert_text(/Free/i)
  end

  test "sample pack is not found in shop search results" do
    visit shop_path(q: "sample")

    # Even when searching for "sample", sample pack should not appear
    assert_no_link @sample_pack.name
  end
end
