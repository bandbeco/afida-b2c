require "test_helper"

class PseoPageValidatorServiceTest < ActiveSupport::TestCase
  def valid_page_data
    JSON.parse(
      Rails.root.join("lib/data/pseo/pages/for/coffee-shops.json").read,
      symbolize_names: true
    )
  end

  test "validates a well-formed page as valid" do
    result = PseoPageValidatorService.new(valid_page_data).validate

    assert result[:valid], "Expected valid page data to pass validation, errors: #{result[:errors]}"
    assert_empty result[:errors]
  end

  test "requires meta section" do
    data = valid_page_data
    data.delete(:meta)

    result = PseoPageValidatorService.new(data).validate

    assert_not result[:valid]
    assert result[:errors].any? { |e| e.include?("meta") }
  end

  test "requires hero section" do
    data = valid_page_data
    data.delete(:hero)

    result = PseoPageValidatorService.new(data).validate

    assert_not result[:valid]
    assert result[:errors].any? { |e| e.include?("hero") }
  end

  test "requires 4-6 packaging_needs entries" do
    data = valid_page_data
    data[:packaging_needs] = data[:packaging_needs].first(3)

    result = PseoPageValidatorService.new(data).validate

    assert_not result[:valid]
    assert result[:errors].any? { |e| e.include?("packaging_needs") }
  end

  test "rejects more than 6 packaging_needs entries" do
    data = valid_page_data
    data[:packaging_needs] = data[:packaging_needs] * 2

    result = PseoPageValidatorService.new(data).validate

    assert_not result[:valid]
    assert result[:errors].any? { |e| e.include?("packaging_needs") }
  end

  test "requires exactly 5 faqs" do
    data = valid_page_data
    data[:faqs] = data[:faqs].first(3)

    result = PseoPageValidatorService.new(data).validate

    assert_not result[:valid]
    assert result[:errors].any? { |e| e.include?("faqs") }
  end

  test "validates intro word count is 150-200 words" do
    data = valid_page_data
    data[:hero][:intro] = "Too short."

    result = PseoPageValidatorService.new(data).validate

    assert_not result[:valid]
    assert result[:errors].any? { |e| e.include?("intro") }
  end

  test "validates FAQ answer word count is 60-100 words" do
    data = valid_page_data
    data[:faqs][0][:answer] = "Too short answer."

    result = PseoPageValidatorService.new(data).validate

    assert_not result[:valid]
    assert result[:errors].any? { |e| e.include?("answer") }
  end

  test "requires sustainability_section" do
    data = valid_page_data
    data.delete(:sustainability_section)

    result = PseoPageValidatorService.new(data).validate

    assert_not result[:valid]
    assert result[:errors].any? { |e| e.include?("sustainability_section") }
  end

  test "requires social_proof section" do
    data = valid_page_data
    data.delete(:social_proof)

    result = PseoPageValidatorService.new(data).validate

    assert_not result[:valid]
    assert result[:errors].any? { |e| e.include?("social_proof") }
  end

  test "requires meta slug" do
    data = valid_page_data
    data[:meta][:slug] = ""

    result = PseoPageValidatorService.new(data).validate

    assert_not result[:valid]
    assert result[:errors].any? { |e| e.include?("slug") }
  end

  test "requires meta seo_title" do
    data = valid_page_data
    data[:meta][:seo_title] = ""

    result = PseoPageValidatorService.new(data).validate

    assert_not result[:valid]
    assert result[:errors].any? { |e| e.include?("seo_title") }
  end
end
