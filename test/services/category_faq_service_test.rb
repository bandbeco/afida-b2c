# frozen_string_literal: true

require "test_helper"

class CategoryFaqServiceTest < ActiveSupport::TestCase
  setup do
    CategoryFaqService.reload!
  end

  test "loads FAQs for a known category slug" do
    faqs = CategoryFaqService.for_category("hot-cups")
    assert_not_nil faqs
    assert_not_empty faqs
  end

  test "returns empty array for unknown category slug" do
    faqs = CategoryFaqService.for_category("nonexistent-slug")
    assert_equal [], faqs
  end

  test "each FAQ has question and answer keys" do
    faqs = CategoryFaqService.for_category("hot-cups")
    faqs.each do |faq|
      assert faq.key?("question"), "FAQ missing 'question' key"
      assert faq.key?("answer"), "FAQ missing 'answer' key"
      assert faq["question"].present?, "FAQ question should not be blank"
      assert faq["answer"].present?, "FAQ answer should not be blank"
    end
  end

  test "returns FAQs for top-level parent categories" do
    faqs = CategoryFaqService.for_category("cups-and-drinks")
    assert_not_empty faqs, "Top-level categories should have FAQs"
  end

  test "YAML file contains expected category slugs" do
    all_slugs = CategoryFaqService.all_slugs
    # Verify key categories are present
    assert_includes all_slugs, "hot-cups"
    assert_includes all_slugs, "cups-and-drinks"
    assert_includes all_slugs, "pizza-boxes"
    assert_includes all_slugs, "napkins"
    assert all_slugs.size >= 25, "Should have FAQs for all categories"
  end
end
