# frozen_string_literal: true

require "application_system_test_case"

class FaqTest < ApplicationSystemTestCase
  test "visiting FAQ page shows all categories" do
    visit faqs_path

    assert_selector "h1", text: "Frequently Asked Questions"
    # Scope to main content to exclude footer and sidebar h2s
    within "main#faq-content" do
      assert_selector "h2", count: 10 # 10 category headers
      assert_selector ".collapse", count: 33 # 33 question accordions
    end
  end

  test "accordion opens and closes questions within same category" do
    visit faqs_path

    # Each category has its own accordion group (independent radio groups)
    within "#about-products" do
      # DaisyUI accordion uses radio inputs (only one open at a time within category)
      collapses = all(".collapse")
      skip "Need at least 2 questions to test accordion behavior" if collapses.count < 2

      first_question = collapses[0]
      second_question = collapses[1]
      first_radio = first_question.find('input[type="radio"]', visible: false)
      second_radio = second_question.find('input[type="radio"]', visible: false)

      # Open the first question
      first_radio.click
      assert first_radio.checked?

      # Opening second question should close the first (same category = same radio group)
      second_radio.click
      assert second_radio.checked?
      assert_not first_radio.checked?
    end
  end

  test "search finds relevant questions" do
    visit faqs_path

    fill_in "q", with: "branded"

    # Wait for debounced search
    sleep 0.5

    assert_text "Search Results"
    assert_selector ".card", minimum: 1
  end

  test "quick links navigate to categories" do
    visit faqs_path

    # Use the sidebar nav with Table of Contents
    within "aside nav" do
      click_link "Custom Printing & Branding"
    end

    # Should scroll to category (check URL hash)
    assert_equal "custom-printing", URI.parse(current_url).fragment
  end

  test "contact CTA appears in sidebar" do
    visit faqs_path

    # Contact info appears in sidebar "Need help?" section
    assert_text "Need help?"
    assert_text "We're here to assist you"
    assert_link "info@afida.com"
    assert_link "0203 302 7719"
  end
end
