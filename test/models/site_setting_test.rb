require "test_helper"

class SiteSettingTest < ActiveSupport::TestCase
  test "instance returns existing record" do
    existing = site_settings(:default)
    assert_equal existing, SiteSetting.instance
  end

  test "instance creates record if none exists" do
    BrandingImage.delete_all
    SiteSetting.delete_all
    assert_difference("SiteSetting.count", 1) do
      setting = SiteSetting.instance
      assert_equal "#ffffff", setting.hero_background_color
    end
  end

  test "validates hex color format" do
    setting = site_settings(:default)

    setting.hero_background_color = "#abcdef"
    assert setting.valid?

    setting.hero_background_color = "#ABCDEF"
    assert setting.valid?

    setting.hero_background_color = "#123456"
    assert setting.valid?

    setting.hero_background_color = "red"
    assert_not setting.valid?

    setting.hero_background_color = "#fff"
    assert_not setting.valid?

    setting.hero_background_color = "#gggggg"
    assert_not setting.valid?

    setting.hero_background_color = ""
    assert_not setting.valid?
  end

  test "collage_images returns at most 4 images" do
    setting = site_settings(:default)
    assert_equal 4, setting.collage_images.size
  end

  test "branding_images are ordered by position" do
    setting = site_settings(:default)
    positions = setting.branding_images.pluck(:position)
    assert_equal positions.sort, positions
  end

  test "destroying setting destroys branding images" do
    setting = site_settings(:default)
    branding_count = setting.branding_images.count
    assert branding_count > 0

    assert_difference("BrandingImage.count", -branding_count) do
      setting.destroy
    end
  end
end
