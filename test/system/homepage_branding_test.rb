# frozen_string_literal: true

require "application_system_test_case"

class HomepageBrandingTest < ApplicationSystemTestCase
  # US1: Visual Discovery - Photo Collage
  test "displays branding section with photo collage" do
    visit root_path

    within "#branding" do
      # Verify 4 collage images are present (branded cups from gallery)
      # Images are inside rounded-xl containers with object-cover styling
      assert_selector "img.object-cover", minimum: 4
    end
  end

  # US2: Value Proposition - Headline
  test "displays headline with gradient text" do
    visit root_path

    within "#branding" do
      assert_text "Brand is who you are."
      assert_text "Branding is how you show up."
    end
  end

  # US2: Value Proposition - Trust Badges
  test "displays trust badges with correct values" do
    visit root_path

    within "#branding" do
      assert_text "Low MOQs"
      assert_text "High Quality Printing"
      assert_text "Free Storage"
    end
  end

  # US3: Taking Action - CTA Button Presence
  test "displays Start Branding CTA button" do
    visit root_path

    within "#branding" do
      assert_link "Start Branding"
    end
  end

  # US3: Taking Action - CTA Navigation
  test "CTA button navigates to branded products page" do
    visit root_path

    within "#branding" do
      click_link "Start Branding"
    end

    assert_current_path branded_products_path
  end
end
