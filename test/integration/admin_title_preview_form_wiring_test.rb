require "test_helper"

class Admin::TitlePreviewFormWiringTest < ActionDispatch::IntegrationTest
  def setup
    @headers = { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }
    @product = products(:one)
    post session_url, params: { email_address: users(:acme_admin).email_address, password: "password" }, headers: @headers
  end

  # The size-driving dimension fields that get mirrored into Title Builder.
  MIRRORED = %w[length_in_mm width_in_mm height_in_mm volume_in_ml weight_in_g].freeze

  test "edit form wires the title-preview controller to the server endpoint" do
    get edit_admin_product_path(@product), headers: @headers
    assert_response :success

    # Controller element carries the preview URL value.
    assert_select "fieldset[data-controller~='title-preview'][data-title-preview-url-value=?]",
                  preview_title_admin_products_path
    # Preview target is the turbo-stream-addressable element.
    assert_select "#title-preview"
    # Title text fields trigger updates.
    assert_select "input[name='product[name]'][data-action*='title-preview#update']"
  end

  test "Title Builder section mirrors the size-driving dimension fields" do
    get edit_admin_product_path(@product), headers: @headers
    assert_response :success

    assert_select "fieldset[data-controller~='title-preview']" do
      MIRRORED.each do |attr|
        # Mirror lives inside the controller (so its action actually fires) and
        # syncs to the real Specifications input. It carries NO name attribute,
        # so it never double-submits alongside the real field.
        assert_select "input[data-field-sync-source-value='product_#{attr}'][data-action*='title-preview#update']:not([name])",
                      true, "expected a mirror input for #{attr} inside Title Builder"
      end
      # depth/diameter are NOT mirrored (derived_size ignores them).
      assert_select "input[data-field-sync-source-value='product_depth_in_mm']", count: 0
      assert_select "input[data-field-sync-source-value='product_diameter_in_mm']", count: 0
    end
  end

  test "Specifications section keeps the real submitting dimension inputs" do
    get edit_admin_product_path(@product), headers: @headers
    assert_response :success

    # The real inputs (with name) that actually submit still exist, exactly once
    # each — the mirror in Title Builder must not add a second submitting field.
    (MIRRORED + %w[depth_in_mm diameter_in_mm]).each do |attr|
      assert_select "input[name='product[#{attr}]']", count: 1
    end
  end
end
