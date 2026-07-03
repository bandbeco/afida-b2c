# frozen_string_literal: true

require "test_helper"

class SearchResultRowTest < ActiveSupport::TestCase
  test "wraps a single product as its representative" do
    product = products(:single_wall_8oz_white)

    row = SearchResultRow.new([ product ])

    assert_equal product, row.representative
    assert_equal product, row.product
  end

  test "title is the product's generated title" do
    product = products(:single_wall_8oz_white)

    row = SearchResultRow.new([ product ])

    assert_equal product.generated_title, row.title
  end

  test "brandable? mirrors the representative" do
    brandable = products(:branded_template_variant)

    assert SearchResultRow.new([ brandable ]).brandable?
    refute SearchResultRow.new([ products(:single_wall_8oz_white) ]).brandable?
  end
end
