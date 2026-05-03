require "test_helper"

class ProductSocialProofTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:single_wall_8oz_white)
  end

  test "renders social-proof block on product page" do
    get product_path(@product)

    assert_select "section[data-test='product-social-proof']"
  end

  test "social-proof block highlights the trust line" do
    get product_path(@product)

    assert_select "section[data-test='product-social-proof']" do
      assert_select "[data-test='social-proof-trust-line']", text: /Trusted by 500\+ UK businesses/i
    end
  end

  test "social-proof block names recognisable customers" do
    get product_path(@product)

    assert_select "section[data-test='product-social-proof']" do
      assert_select "[data-test='social-proof-customers']", text: /Marriott/i
      assert_select "[data-test='social-proof-customers']", text: /Hawksmoor/i
    end
  end

  test "social-proof block renders the avatar row of client logos next to the trust line" do
    get product_path(@product)

    assert_select "section[data-test='product-social-proof']" do
      assert_select "[data-test='social-proof-avatar-row'] img", minimum: 5
    end
  end

  test "social-proof block renders the full client logo conveyor" do
    get product_path(@product)

    assert_select "section[data-test='product-social-proof']" do
      assert_select "[data-test='social-proof-logo-conveyor']"
    end
  end

  test "social-proof block renders three customer testimonials" do
    get product_path(@product)

    assert_select "section[data-test='product-social-proof']" do
      assert_select "[data-test='social-proof-testimonial']", count: 3
    end
  end

  test "each testimonial has 5 stars, a quote, and an attribution" do
    get product_path(@product)

    assert_select "[data-test='social-proof-testimonial']" do |testimonials|
      testimonials.each do |t|
        assert_select t, "[data-test='social-proof-stars'] svg", count: 5
        assert_select t, "blockquote"
        assert_select t, "[data-test='social-proof-attribution']"
      end
    end
  end

  test "social-proof block links to all Google reviews when GBP is configured" do
    with_gbp_configured do
      get product_path(@product)

      assert_select "section[data-test='product-social-proof']" do
        assert_select "[data-test='social-proof-google-link'] a[href*='google.com']", text: /read all reviews/i
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
