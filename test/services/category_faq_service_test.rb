# frozen_string_literal: true

require "test_helper"

class CategoryFaqsTest < ActiveSupport::TestCase
  test "category faqs column defaults to empty array" do
    category = Category.create!(name: "Test", slug: "test-faq-default")
    assert_equal [], category.faqs
  end

  test "category can store FAQ entries" do
    category = categories(:cups)
    faqs = [
      { "question" => "What cups do you offer?", "answer" => "We offer paper cups in various sizes." },
      { "question" => "Are your cups compostable?", "answer" => "Yes, our cups are PLA-lined and commercially compostable." }
    ]

    category.update!(faqs: faqs)
    category.reload

    assert_equal 2, category.faqs.size
    assert_equal "What cups do you offer?", category.faqs.first["question"]
    assert_equal "Yes, our cups are PLA-lined and commercially compostable.", category.faqs.last["answer"]
  end

  test "category faqs can be cleared" do
    category = categories(:cups)
    category.update!(faqs: [ { "question" => "Test?", "answer" => "Yes." } ])
    category.update!(faqs: [])
    category.reload

    assert_equal [], category.faqs
  end
end
