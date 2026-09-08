# frozen_string_literal: true

require "test_helper"

class HomepageAgentReadabilityTest < ActionDispatch::IntegrationTest
  test "heading levels never skip a level" do
    get root_path

    levels = Nokogiri::HTML(response.body).css("h1, h2, h3, h4, h5, h6").map { |h| h.name[1].to_i }
    assert_equal 1, levels.first, "page must start with an H1"
    levels.each_cons(2) do |previous, current|
      assert_operator current, :<=, previous + 1, "heading jumps from h#{previous} to h#{current}"
    end
  end

  test "branding section exposes its headline as a real heading" do
    get root_path

    assert_select "section#branding h2", text: /Your Logo\.\s+On Things People Hold\./
    assert_select "section#branding h3", text: "Low MOQs"
    assert_select "section#branding h4", count: 0
    assert_select "section#branding p[role=heading]", count: 0
  end

  test "homepage HTML carries no indentation or comments" do
    get root_path

    assert_response :success
    refute_match(/^[ \t]+\S/, response.body)
    refute_includes response.body, "<!--"
  end

  test "raw homepage HTML has a clear H1 and at least 500 characters of visible text" do
    get root_path

    doc = Nokogiri::HTML(response.body)
    doc.search("script, style, noscript, svg").remove
    text = doc.text.gsub(/\s+/, " ").strip

    assert_select "h1"
    assert_operator text.length, :>=, 500
    assert_operator text.length.to_f / response.body.bytesize, :>=, 0.05,
      "content ratio #{(text.length.to_f / response.body.bytesize * 100).round(1)}% is below 5% (#{text.length} chars / #{response.body.bytesize} bytes)"
  end

  test "hero names Afida in raw HTML before the H1" do
    get root_path

    h1 = Nokogiri::HTML(response.body).at("h1")
    kicker = h1&.previous_element

    assert kicker, "expected a sibling before the H1"
    assert_equal "Afida", kicker.text.strip
  end

  test "homepage catalogue section is real HTML copy with sequential subheadings" do
    get root_path

    assert_select "section#what-afida-supplies h2", text: /Afida/
    assert_select "section#what-afida-supplies h3", minimum: 3
    assert_select "section#what-afida-supplies p", minimum: 4
    assert_includes css_select("section#what-afida-supplies").text, "Unit 27, The Metro Centre"
    assert_includes css_select("section#what-afida-supplies").text, "hello@afida.com"
  end

  test "HEAD Content-Length matches the compacted GET body" do
    get root_path
    get_length = response.headers["Content-Length"]
    get_type = response.media_type

    head root_path

    assert_response :success
    assert_equal get_type, response.media_type
    assert_equal get_length, response.headers["Content-Length"]
    assert_equal "", response.body
  end
end
