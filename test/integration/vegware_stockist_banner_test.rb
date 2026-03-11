# frozen_string_literal: true

require "test_helper"

class VegwareStockistBannerTest < ActionDispatch::IntegrationTest
  test "vegware stockist banner is displayed on the homepage" do
    get root_url
    assert_response :success
    assert_select "[data-testid='vegware-stockist-banner']", count: 1
    assert_select "[data-testid='vegware-stockist-banner']", text: /Official Stockist/
  end

  test "vegware stockist banner links to vegware page" do
    get root_url
    assert_response :success
    assert_select "[data-testid='vegware-stockist-banner'] a[href=?]", "/vegware"
  end

  test "vegware stockist banner has a dismiss button" do
    get root_url
    assert_response :success
    assert_select "[data-testid='vegware-stockist-banner'] button[data-action*='dismissable-banner#dismiss']"
  end

  test "vegware stockist banner appears on other pages" do
    get faqs_url
    assert_response :success
    assert_select "[data-testid='vegware-stockist-banner']", count: 1
  end
end
