# frozen_string_literal: true

require "test_helper"

class FaqsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get faqs_url
    assert_response :success
  end

  test "index loads all categories" do
    get faqs_url
    assert_response :success
    assert_select "h1", text: "Frequently Asked Questions (FAQs)"
    # Verify we see accordion items for all questions (33 questions total across 10 categories)
    assert_select ".collapse", count: 33
  end

  test "index performs search when query present" do
    get faqs_url, params: { q: "branded" }
    assert_response :success
    assert_select "h2", text: /Search Results/
  end

  test "index accessible without authentication" do
    get faqs_url
    assert_response :success
  end

  test "search query is displayed in results" do
    get faqs_url, params: { q: "shipping" }
    assert_response :success
    assert_select "h2", text: /Search Results for "shipping"/
  end

  # The page has its own search field, so the navbar search bar is suppressed.
  test "index does not render the navbar search bar" do
    get faqs_url
    assert_select "[data-testid='navbar-search-bar']", count: 0
  end
end
