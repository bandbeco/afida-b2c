# frozen_string_literal: true

require "test_helper"

class AgentFriendlyNotFoundTest < ActionDispatch::IntegrationTest
  MISSING_PATH = "/some-path-that-does-not-exist"

  setup do
    production_env_config = Rails.application.env_config.merge("action_dispatch.show_detailed_exceptions" => false)
    Rails.application.stubs(:env_config).returns(production_env_config)
  end

  test "unknown path returns a real 404 with the branded HTML page" do
    get MISSING_PATH

    assert_response :not_found
    assert_match(/\Atext\/html/, response.media_type + ";")
    assert_select "h1", text: "This page packed up and left"
  end

  test "HTML 404 page points agents at the sitemap and llms.txt" do
    get MISSING_PATH

    assert_select "a[href='/sitemap.xml']"
    assert_select "a[href='/llms.txt']"
  end

  test "HTML 404 page links to live category URLs, not renamed slugs" do
    get MISSING_PATH

    assert_select "a[href='/categories/cups-and-accessories']"
    assert_select "a[href='/categories/food-containers']"
    assert_select "a[href='/categories/cups-and-drinks']", count: 0
    assert_select "a[href='/categories/hot-food']", count: 0
  end

  test "unknown path returns a short markdown body when Accept: text/markdown" do
    get MISSING_PATH, headers: { "Accept" => "text/markdown" }

    assert_response :not_found
    assert_equal "text/markdown", response.media_type
    assert_match(/^# This page packed up and left/, response.body)
    assert_includes response.body, "](/sitemap.xml)"
    assert_includes response.body, "](/llms.txt)"
    assert_includes response.body, "](/shop)"
    assert_operator response.body.length, :<, 2000
  end

  test "unknown product slug returns markdown 404 when Accept: text/markdown" do
    get product_path(slug: "no-such-product"), headers: { "Accept" => "text/markdown" }

    assert_response :not_found
    assert_equal "text/markdown", response.media_type
    assert_includes response.body, "](/llms.txt)"
  end

  test "unknown category slug returns markdown 404 when Accept: text/markdown" do
    get category_path(id: "no-such-category"), headers: { "Accept" => "text/markdown" }

    assert_response :not_found
    assert_equal "text/markdown", response.media_type
  end

  test "markdown conversion wraps the exception renderer so rescued 404s are converted" do
    Rails.application.app
    names = Rails.application.middleware.map(&:name)

    assert_operator names.index("MarkdownForAgentsMiddleware"), :<, names.index("ActionDispatch::ShowExceptions")
    assert_operator names.index("HtmlCompactorMiddleware"), :<, names.index("ActionDispatch::ShowExceptions")
  end
end
