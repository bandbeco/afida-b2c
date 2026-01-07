require "test_helper"

class VariantSelectorHelperTest < ActionView::TestCase
  # T011: Tests for natural_sort_options helper (accepts array of hashes with :value key)

  # Helper to convert string array to hash array format
  def to_options(values)
    values.map { |v| { value: v, label: v } }
  end

  # Helper to extract values from sorted options
  def extract_values(options)
    options.map { |o| o[:value] }
  end

  test "natural_sort_options sorts oz sizes numerically" do
    input = to_options([ "16oz", "8oz", "12oz", "4oz" ])
    expected = [ "4oz", "8oz", "12oz", "16oz" ]
    assert_equal expected, extract_values(natural_sort_options(input))
  end

  test "natural_sort_options sorts mm dimensions numerically" do
    input = to_options([ "8x200mm", "6x140mm", "10x250mm" ])
    expected = [ "6x140mm", "8x200mm", "10x250mm" ]
    assert_equal expected, extract_values(natural_sort_options(input))
  end

  test "natural_sort_options sorts inch sizes numerically" do
    input = to_options([ '14"', '10"', '7"', '12"' ])
    expected = [ '7"', '10"', '12"', '14"' ]
    assert_equal expected, extract_values(natural_sort_options(input))
  end

  test "natural_sort_options places non-numeric values last" do
    input = to_options([ "Large", "8oz", "Small", "12oz" ])
    expected = [ "8oz", "12oz", "Large", "Small" ]
    assert_equal expected, extract_values(natural_sort_options(input))
  end

  test "natural_sort_options handles empty array" do
    assert_equal [], natural_sort_options([])
  end

  test "natural_sort_options handles all non-numeric values alphabetically" do
    input = to_options([ "White", "Black", "Natural" ])
    expected = [ "Black", "Natural", "White" ]
    assert_equal expected, extract_values(natural_sort_options(input))
  end

  test "natural_sort_options handles mixed formats" do
    input = to_options([ "Small", "8oz", "Medium", "16oz", "Large" ])
    # Numeric first (sorted numerically), then text (sorted alphabetically)
    expected = [ "8oz", "16oz", "Large", "Medium", "Small" ]
    assert_equal expected, extract_values(natural_sort_options(input))
  end
end
