require "test_helper"

class ProductTrustStripTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:single_wall_8oz_white)
  end

  test "renders a compact trust strip on the PDP" do
    get product_path(@product)

    assert_select "[data-test='product-trust-strip']"
  end

  test "trust strip mentions the 500+ UK businesses line" do
    get product_path(@product)

    assert_select "[data-test='product-trust-strip']", text: /500\+\s*UK businesses/i
  end

  test "trust strip shows five stars" do
    get product_path(@product)

    assert_select "[data-test='product-trust-strip'] [data-test='trust-strip-stars'] svg", count: 5
  end

  test "trust strip shows the client logo avatar row" do
    get product_path(@product)

    assert_select "[data-test='product-trust-strip'] [data-test='trust-strip-avatars'] img", minimum: 5
  end

  test "trust strip links to Google reviews when GBP is configured" do
    with_gbp_configured do
      get product_path(@product)

      assert_select "[data-test='product-trust-strip'] a[href*='google.com']" do
        assert_select "[data-test='trust-strip-stars']"
      end
    end
  end

  private

  def with_gbp_configured
    SeoHelper.module_eval do
      alias_method :__orig_gbp_configured?, :gbp_configured?
      alias_method :__orig_gbp_profile_url, :gbp_profile_url
      define_method(:gbp_configured?) { true }
      define_method(:gbp_profile_url) { "https://www.google.com/maps?cid=7446902719763895901" }
    end
    yield
  ensure
    SeoHelper.module_eval do
      alias_method :gbp_configured?, :__orig_gbp_configured?
      alias_method :gbp_profile_url, :__orig_gbp_profile_url
      remove_method :__orig_gbp_configured?
      remove_method :__orig_gbp_profile_url
    end
  end
end
