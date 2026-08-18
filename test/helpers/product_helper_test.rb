require "test_helper"

class ProductHelperTest < ActionView::TestCase
  setup do
    @cup_product = products(:single_wall_8oz_white)
  end

  test "product_photo_tag returns image tag when photo attached" do
    skip "Photo not attached in fixture" unless @cup_product.product_photo.attached?

    result = product_photo_tag(@cup_product.product_photo, alt: "Test product")
    assert_match /img/, result
  end

  test "product_photo_tag returns placeholder for missing photo" do
    product_without_photo = products(:two)

    result = product_photo_tag(product_without_photo.product_photo, alt: "Test")
    assert_match /placeholder|svg|📦/, result.to_s
  end
end
