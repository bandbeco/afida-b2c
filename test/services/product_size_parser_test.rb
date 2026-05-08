# frozen_string_literal: true

require "test_helper"

class ProductSizeParserTest < ActiveSupport::TestCase
  # Explicit ml present in the string — pluck it directly.
  test "extracts ml from 'oz / ml' format" do
    assert_equal 227, ProductSizeParser.parse("8oz / 227ml")
    assert_equal 340, ProductSizeParser.parse("12oz / 340ml")
    assert_equal 114, ProductSizeParser.parse("4oz / 114ml")
    assert_equal 455, ProductSizeParser.parse("16oz / 455ml")
  end

  test "extracts ml from standalone ml strings" do
    assert_equal 500, ProductSizeParser.parse("500ml")
    assert_equal 1000, ProductSizeParser.parse("1000ml")
    assert_equal 750, ProductSizeParser.parse("750ml")
  end

  test "extracts first ml number from container codes like 'No.1 (755ml / 26oz)'" do
    assert_equal 755, ProductSizeParser.parse("No.1 (755ml / 26oz)")
    assert_equal 1900, ProductSizeParser.parse("No.3 (1900ml / 69oz)")
    assert_equal 1300, ProductSizeParser.parse("No.8 (1300ml / 49oz)")
  end

  # No ml — derive from oz when possible. Catalog uses UK fl oz (28.4131 ml).
  test "converts 'oz only' strings to ml using UK fluid ounces" do
    # 16oz × 28.4131 ≈ 455 (matches the labelled "16oz / 455ml" elsewhere).
    assert_in_delta 455, ProductSizeParser.parse("16oz"), 1
    assert_in_delta 341, ProductSizeParser.parse("12oz"), 1
  end

  test "treats 'oz Compatible' (lid sizing) as the cup capacity it pairs with" do
    # A 12oz lid sits on a 12oz cup → sort it as a 12oz product (~341ml UK).
    assert_in_delta 341, ProductSizeParser.parse("12oz Compatible"), 1
    assert_in_delta 256, ProductSizeParser.parse("9oz Compatible"), 1
  end

  test "uses lower bound for compatibility ranges" do
    # "16oz-20oz Compatible" → sort with the 16oz cohort (UK: 455ml).
    assert_in_delta 455, ProductSizeParser.parse("16oz-20oz Compatible"), 1
    # "8-12oz" → sort with the 8oz cohort (UK: 227ml).
    assert_in_delta 227, ProductSizeParser.parse("8-12oz"), 1
    # "500-1000ml" → 500ml cohort.
    assert_equal 500, ProductSizeParser.parse("500-1000ml")
  end

  # Strings that aren't capacity at all — return nil so SQL ordering falls back to position/id.
  test "returns nil for non-capacity strings" do
    assert_nil ProductSizeParser.parse("6 x 150mm")
    assert_nil ProductSizeParser.parse("160mm")
    assert_nil ProductSizeParser.parse("23 x 23cm")
    assert_nil ProductSizeParser.parse("12 inch / 310 x 310mm")
    assert_nil ProductSizeParser.parse("4-Cup")
    assert_nil ProductSizeParser.parse("Half-Pint to Line")
    assert_nil ProductSizeParser.parse("Small")
    assert_nil ProductSizeParser.parse("Medium")
    assert_nil ProductSizeParser.parse("Large")
  end

  test "returns nil for blank or nil input" do
    assert_nil ProductSizeParser.parse(nil)
    assert_nil ProductSizeParser.parse("")
    assert_nil ProductSizeParser.parse("   ")
  end
end
