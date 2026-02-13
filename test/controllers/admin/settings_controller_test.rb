require "test_helper"

class Admin::SettingsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @headers = { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }
    @admin = users(:acme_admin)
    @site_setting = site_settings(:default)
    sign_in_as(@admin)
  end

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }, headers: @headers
  end

  # === Show ===

  test "should get show" do
    get admin_settings_path, headers: @headers
    assert_response :success
    assert_match /Site Settings/, response.body
    assert_match /Hero Banner/, response.body
    assert_match /Branding Images/, response.body
  end

  # === Update hero settings ===

  test "should update hero background color" do
    patch admin_settings_path, headers: @headers, params: {
      site_setting: { hero_background_color: "#ff5500" }
    }
    assert_redirected_to admin_settings_path
    @site_setting.reload
    assert_equal "#ff5500", @site_setting.hero_background_color
  end

  test "should reject invalid hex color" do
    patch admin_settings_path, headers: @headers, params: {
      site_setting: { hero_background_color: "not-a-color" }
    }
    assert_response :unprocessable_entity
    @site_setting.reload
    assert_equal "#ffffff", @site_setting.hero_background_color
  end

  test "should upload hero image" do
    image = fixture_file_upload("test/fixtures/files/test_image.png", "image/png")
    patch admin_settings_path, headers: @headers, params: {
      site_setting: { hero_image: image }
    }
    assert_redirected_to admin_settings_path
    @site_setting.reload
    assert @site_setting.hero_image.attached?
  end

  # === Destroy hero image ===

  test "should destroy hero image" do
    # Attach an image first
    @site_setting.hero_image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/test_image.png")),
      filename: "test.png",
      content_type: "image/png"
    )
    assert @site_setting.hero_image.attached?

    delete hero_image_admin_settings_path, headers: @headers
    assert_redirected_to admin_settings_path
    @site_setting.reload
    assert_not @site_setting.hero_image.attached?
  end

  test "should handle destroying hero image when none exists" do
    @site_setting.hero_image.purge if @site_setting.hero_image.attached?
    assert_not @site_setting.hero_image.attached?

    delete hero_image_admin_settings_path, headers: @headers
    assert_redirected_to admin_settings_path
    assert_match /No hero image to remove/, flash[:alert]
  end

  # === Add branding image ===

  test "should add branding image" do
    image = fixture_file_upload("test/fixtures/files/test_image.png", "image/png")
    assert_difference("BrandingImage.count", 1) do
      post branding_images_admin_settings_path, headers: @headers, params: {
        branding_image: { image: image, alt_text: "New branding image" }
      }
    end
    assert_redirected_to admin_settings_path
  end

  test "should reject branding image without alt text" do
    image = fixture_file_upload("test/fixtures/files/test_image.png", "image/png")
    assert_no_difference("BrandingImage.count") do
      post branding_images_admin_settings_path, headers: @headers, params: {
        branding_image: { image: image, alt_text: "" }
      }
    end
    assert_redirected_to admin_settings_path
    assert_match /Alt text/, flash[:alert]
  end

  # === Remove branding image ===

  test "should remove branding image" do
    branding_image = branding_images(:five)
    assert_difference("BrandingImage.count", -1) do
      delete remove_branding_image_admin_settings_path(id: branding_image.id), headers: @headers
    end
    assert_redirected_to admin_settings_path
  end

  # === Reorder branding images ===

  test "should move branding image higher" do
    image_two = branding_images(:two)
    patch move_branding_image_higher_admin_settings_path(id: image_two.id), headers: @headers
    assert_redirected_to admin_settings_path
    image_two.reload
    assert_equal 1, image_two.position
  end

  test "should move branding image lower" do
    image_one = branding_images(:one)
    patch move_branding_image_lower_admin_settings_path(id: image_one.id), headers: @headers
    assert_redirected_to admin_settings_path
    image_one.reload
    assert_equal 2, image_one.position
  end

  # === Update branding image alt text ===

  test "should update branding image alt text" do
    branding_image = branding_images(:one)
    patch update_branding_image_admin_settings_path(id: branding_image.id), headers: @headers, params: {
      branding_image: { alt_text: "Updated alt text" }
    }
    assert_redirected_to admin_settings_path
    branding_image.reload
    assert_equal "Updated alt text", branding_image.alt_text
  end

  # === Non-admin redirect ===

  test "non-admin should be redirected" do
    # Sign out by resetting session
    delete session_path, headers: @headers

    # Sign in as non-admin
    consumer = users(:consumer)
    sign_in_as(consumer)

    get admin_settings_path, headers: @headers
    assert_redirected_to root_path
  end

  test "unauthenticated user should be redirected" do
    delete session_path, headers: @headers

    get admin_settings_path, headers: @headers
    assert_response :redirect
  end
end
