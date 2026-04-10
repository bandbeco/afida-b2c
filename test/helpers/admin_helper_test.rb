# frozen_string_literal: true

require "test_helper"

class AdminHelperTest < ActionView::TestCase
  include AdminHelper

  # ==========================================================================
  # json_field_value
  # ==========================================================================

  test "json_field_value returns empty string for empty array" do
    post = BlogPost.new(title: "Test", body: "Content")
    assert_equal "", json_field_value(post, :faq_items)
  end

  test "json_field_value returns pretty JSON for populated array" do
    post = BlogPost.new(
      title: "Test",
      body: "Content",
      faq_items: [ { "question" => "Why?", "answer" => "Because." } ]
    )
    result = json_field_value(post, :faq_items)
    assert_equal JSON.pretty_generate(post.faq_items), result
    assert_includes result, "\"question\": \"Why?\""
  end

  test "json_field_value passes through raw string on validation failure" do
    post = BlogPost.new(title: "Test", body: "Content")
    post[:faq_items] = "not valid json {"
    assert_equal "not valid json {", json_field_value(post, :faq_items)
  end
end
