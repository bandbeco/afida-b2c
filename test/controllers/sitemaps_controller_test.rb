require "test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  test "should get sitemap xml" do
    get sitemap_url(format: :xml)
    assert_response :success
    assert_equal "application/xml; charset=utf-8", response.content_type
  end

  test "sitemap includes products" do
    get sitemap_url(format: :xml)

    product = products(:single_wall_cups)
    assert_includes response.body, product.slug
  end

  test "sitemap is valid XML" do
    get sitemap_url(format: :xml)

    doc = Nokogiri::XML(response.body)
    errors = doc.errors
    assert_empty errors, "Sitemap XML has errors: #{errors.map(&:message).join(', ')}"
  end

  test "does not set a datafast_visitor_id tracking cookie" do
    get sitemap_url(format: :xml)
    assert_nil cookies[:datafast_visitor_id],
      "crawler-only endpoint should not emit a visitor tracking cookie"
  end
end
