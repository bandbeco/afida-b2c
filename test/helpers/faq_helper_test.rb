# frozen_string_literal: true

require "test_helper"

class FaqHelperTest < ActionView::TestCase
  test "generates valid FAQ schema markup" do
    categories = FaqService.all_categories
    schema_html = faq_schema_markup(categories)

    assert_includes schema_html, "application/ld+json"
    assert_includes schema_html, "FAQPage"
    assert_includes schema_html, "Question"
  end

  test "includes all questions in schema" do
    categories = FaqService.all_categories
    schema_html = faq_schema_markup(categories)

    # Count questions in YAML
    total_questions = categories.sum { |cat| cat["questions"].size }

    # Count Question types in schema
    question_count = schema_html.scan(/"@type":"Question"/).size

    assert_equal total_questions, question_count
  end

  test "category_faq_schema_markup generates FAQPage schema for category FAQs" do
    faqs = CategoryFaqService.for_category("hot-cups")
    schema_html = category_faq_schema_markup(faqs)

    assert_includes schema_html, "application/ld+json"
    assert_includes schema_html, "FAQPage"
    assert_includes schema_html, "Question"
  end

  test "category_faq_schema_markup includes all questions" do
    faqs = CategoryFaqService.for_category("hot-cups")
    schema_html = category_faq_schema_markup(faqs)

    question_count = schema_html.scan(/"@type":"Question"/).size
    assert_equal faqs.size, question_count
  end

  test "category_faq_schema_markup strips markdown links from answers" do
    faqs = [ { "question" => "Test?", "answer" => "Visit [our shop](/shop) for details." } ]
    schema_html = category_faq_schema_markup(faqs)

    assert_includes schema_html, "Visit our shop for details."
    refute_includes schema_html, "[our shop]"
  end

  test "category_faq_schema_markup returns empty string for empty faqs" do
    assert_equal "", category_faq_schema_markup([])
  end
end
