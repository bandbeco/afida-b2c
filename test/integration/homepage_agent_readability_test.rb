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
end
