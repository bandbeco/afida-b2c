require "test_helper"

class VariantSelectorHelperTest < ActionView::TestCase
  # T011: Tests for natural_sort_sizes helper

  test "natural_sort_sizes sorts oz sizes numerically" do
    input = [ "16oz", "8oz", "12oz", "4oz" ]
    expected = [ "4oz", "8oz", "12oz", "16oz" ]
    assert_equal expected, natural_sort_sizes(input)
  end

  test "natural_sort_sizes sorts mm dimensions numerically" do
    input = [ "8x200mm", "6x140mm", "10x250mm" ]
    expected = [ "6x140mm", "8x200mm", "10x250mm" ]
    assert_equal expected, natural_sort_sizes(input)
  end

  test "natural_sort_sizes sorts inch sizes numerically" do
    input = [ '14"', '10"', '7"', '12"' ]
    expected = [ '7"', '10"', '12"', '14"' ]
    assert_equal expected, natural_sort_sizes(input)
  end

  test "natural_sort_sizes places non-numeric values last" do
    input = [ "Large", "8oz", "Small", "12oz" ]
    expected = [ "8oz", "12oz", "Large", "Small" ]
    assert_equal expected, natural_sort_sizes(input)
  end

  test "natural_sort_sizes handles empty array" do
    assert_equal [], natural_sort_sizes([])
  end

  test "natural_sort_sizes handles all non-numeric values alphabetically" do
    input = [ "White", "Black", "Natural" ]
    expected = [ "Black", "Natural", "White" ]
    assert_equal expected, natural_sort_sizes(input)
  end

  test "natural_sort_sizes handles mixed formats" do
    input = [ "Small", "8oz", "Medium", "16oz", "Large" ]
    # Numeric first (sorted numerically), then text (sorted alphabetically)
    expected = [ "8oz", "16oz", "Large", "Medium", "Small" ]
    assert_equal expected, natural_sort_sizes(input)
  end
end
