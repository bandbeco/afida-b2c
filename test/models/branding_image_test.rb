require "test_helper"

class BrandingImageTest < ActiveSupport::TestCase
  test "validates alt_text presence" do
    image = BrandingImage.new(site_setting: site_settings(:default), alt_text: "")
    assert_not image.valid?
    assert_includes image.errors[:alt_text], "can't be blank"
  end

  test "valid with alt_text and site_setting" do
    image = BrandingImage.new(site_setting: site_settings(:default), alt_text: "Test image")
    assert image.valid?
  end

  test "acts_as_list ordering within site_setting" do
    image_one = branding_images(:one)
    image_two = branding_images(:two)

    assert_equal 1, image_one.position
    assert_equal 2, image_two.position

    image_two.move_higher
    image_one.reload
    image_two.reload

    assert_equal 1, image_two.position
    assert_equal 2, image_one.position
  end

  test "belongs to site_setting" do
    image = branding_images(:one)
    assert_equal site_settings(:default), image.site_setting
  end
end
