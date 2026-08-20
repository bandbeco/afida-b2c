require "test_helper"

# The per-unit rate is the number trade buyers compare across suppliers and pack
# sizes. It leads the grid cards already; the product page has to quote it too,
# or a £93 lid pack next to a £46 tray reads as a pricing error.
class ProductUnitPriceTest < ActionDispatch::IntegrationTest
  test "the price line quotes the per-unit rate for a pack product" do
    get product_path(products(:flat_lid_8oz))

    assert_select "[data-test='pdp-unit-price']", text: /1\.5p\s*\/\s*unit/
  end

  test "the price line omits the per-unit rate for a single-unit product" do
    single = products(:flat_lid_8oz)
    single.update!(pac_size: 1)

    get product_path(single)

    assert_select "[data-test='pdp-unit-price']", count: 0
  end

  test "a tiered product quotes the selected tier's unit price, not a range" do
    get product_path(products(:single_wall_8oz_white))

    # Tiers are seeded with the product's default price/pac size; the tier
    # controller rewrites this as the buyer picks a different case.
    assert_select "[data-test='pdp-unit-price']" do |elements|
      assert_no_match(/from/i, elements.first.text)
    end
  end
end
