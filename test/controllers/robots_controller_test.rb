require "test_helper"

class RobotsControllerTest < ActionDispatch::IntegrationTest
  test "should get robots txt" do
    get "/robots.txt"
    assert_response :success
    assert_equal "text/plain; charset=utf-8", response.content_type
  end

  test "robots txt includes sitemap" do
    get "/robots.txt"
    assert_includes response.body, "Sitemap:"
    assert_includes response.body, "/sitemap.xml"
  end

  test "robots txt disallows admin" do
    get "/robots.txt"
    assert_includes response.body, "Disallow: /admin/"
  end

  test "robots txt includes explicit AI crawler allow rules" do
    get "/robots.txt"
    assert_includes response.body, "User-agent: GPTBot"
    assert_includes response.body, "User-agent: ClaudeBot"
    assert_includes response.body, "User-agent: PerplexityBot"
    assert_includes response.body, "User-agent: Google-Extended"
    assert_includes response.body, "User-agent: Applebot-Extended"
  end

  test "robots txt AI crawler blocks include disallow rules" do
    get "/robots.txt"
    # GPTBot section should have its own disallow rules
    lines = response.body.lines.map(&:strip)
    gptbot_index = lines.index("User-agent: GPTBot")
    assert gptbot_index, "GPTBot user-agent not found"
    # After GPTBot, there should be Allow and Disallow rules before the next User-agent
    section = lines[(gptbot_index + 1)..].take_while { |l| !l.start_with?("User-agent:") }
    assert section.any? { |l| l.include?("Allow: /") }
    assert section.any? { |l| l.include?("Disallow: /admin/") }
  end
end
