# frozen_string_literal: true

require "test_helper"

class SearchResultRowTest < ActiveSupport::TestCase
  test "collapse folds same-family non-brandable products into one row" do
    family_products = products(:single_wall_8oz_white, :single_wall_12oz_white, :single_wall_8oz_black)

    rows = SearchResultRow.collapse(family_products)

    assert_equal 1, rows.size
    assert rows.first.family?
    assert_equal family_products.size, rows.first.variant_count
  end

  test "collapse keeps the best-ranked member as the representative" do
    ordered = [ products(:single_wall_12oz_white), products(:single_wall_8oz_white) ]

    row = SearchResultRow.collapse(ordered).first

    assert_equal products(:single_wall_12oz_white), row.representative
  end

  test "collapse preserves first-appearance order across families" do
    loose = products(:one)
    familied = products(:single_wall_8oz_white)

    rows = SearchResultRow.collapse([ loose, familied ])

    assert_equal loose, rows.first.representative
    assert_equal familied.product_family, rows.last.representative.product_family
  end

  test "collapse never folds brandable templates" do
    brandable = products(:branded_template_variant)

    rows = SearchResultRow.collapse([ brandable, brandable ])

    assert_equal 2, rows.size
    refute rows.first.family?
  end

  test "family? is false for a lone familied member" do
    row = SearchResultRow.collapse([ products(:single_wall_8oz_white) ]).first

    refute row.family?
    assert_equal products(:single_wall_8oz_white).generated_title, row.title
  end

  test "size_range spans smallest to largest by numeric prefix" do
    products(:single_wall_8oz_white).update_columns(size: "8oz")
    products(:single_wall_12oz_white).update_columns(size: "12oz")
    products(:single_wall_8oz_black).update_columns(size: "4oz")

    row = SearchResultRow.collapse(
      products(:single_wall_8oz_white, :single_wall_12oz_white, :single_wall_8oz_black)
    ).first

    assert_equal "4oz - 12oz", row.size_range
  end

  test "size_range is nil when no member carries a size" do
    members = products(:single_wall_8oz_white, :single_wall_12oz_white)
    members.each { |p| p.update_columns(size: nil) }

    row = SearchResultRow.collapse(members).first

    assert_nil row.size_range
  end

  test "from_price is the cheapest member price" do
    products(:single_wall_8oz_white).update_columns(price: 42.30)
    products(:single_wall_12oz_white).update_columns(price: 55.00)

    row = SearchResultRow.collapse(
      products(:single_wall_8oz_white, :single_wall_12oz_white)
    ).first

    assert_equal BigDecimal("42.30"), row.from_price
  end
end
