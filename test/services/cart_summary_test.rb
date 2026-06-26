# frozen_string_literal: true

require "test_helper"

# CartSummary is the single source of truth for the cart-totals lines rendered on
# the cart page and in the cart drawer, mirroring OrderSummary for orders. These
# tests pin the line order, labels, money format and the discount-visibility rule
# so the two cart surfaces (and, by matching OrderSummary's shape, the order
# surfaces) can't drift.
class CartSummaryTest < ActiveSupport::TestCase
  include StripeTestHelper

  setup do
    @cart = Cart.create!
    # £20 subtotal, below the free-shipping threshold so shipping is charged.
    @cart.cart_items.create!(product: products(:one), quantity: 2, price: 10.00)
  end

  # A no-discount cart omits the discount line and keeps the canonical order:
  # Subtotal -> Shipping -> VAT -> Total (matching OrderSummary).
  test "without a discount lists subtotal, shipping, vat, total in order" do
    kinds = CartSummary.lines(@cart).map { |l| l[:kind] }
    assert_equal %i[subtotal shipping vat total], kinds
  end

  test "labels subtotal, shipping and total plainly and vat with the rate" do
    by_kind = CartSummary.lines(@cart).index_by { |l| l[:kind] }
    assert_equal "Subtotal", by_kind[:subtotal][:label]
    assert_equal "Shipping", by_kind[:shipping][:label]
    assert_equal "VAT (20%)", by_kind[:vat][:label]
    assert_equal "Total", by_kind[:total][:label]
  end

  test "formats subtotal, vat and total as GBP and shipping via the cart display" do
    by_kind = CartSummary.lines(@cart).index_by { |l| l[:kind] }
    # subtotal 20.00, shipping 6.99, vat (20+6.99)*0.2 = 5.398, total summed-rounded.
    assert_equal "£20.00", by_kind[:subtotal][:amount]
    assert_equal "£6.99", by_kind[:shipping][:amount]
    assert_equal "£5.40", by_kind[:vat][:amount]
    assert_equal "£32.39", by_kind[:total][:amount]
  end

  test "the total line matches the cart's display_total_amount (summed rounded lines)" do
    total = CartSummary.lines(@cart).find { |l| l[:kind] == :total }
    assert_equal ActiveSupport::NumberHelper.number_to_currency(@cart.display_total_amount), total[:amount]
  end

  # Shipping shows the cart's display string, not a bare amount: "Free" at/above
  # the threshold so the cart and the order surfaces agree on the wording.
  test "shows free shipping as Free" do
    free_cart = Cart.create!
    variant = Product.create!(
      category: categories(:cups),
      name: "Free-ship pack",
      sku: "TEST-CARTSUMMARY-FREE-SHIP",
      price: Shipping::FREE_SHIPPING_THRESHOLD,
      pac_size: 1,
      active: true
    )
    free_cart.cart_items.create!(product: variant, quantity: 1, price: variant.price)

    shipping = CartSummary.lines(free_cart).find { |l| l[:kind] == :shipping }
    assert_equal "Free", shipping[:amount]
  end

  # A discounted cart inserts the discount line AFTER shipping and BEFORE vat, so it
  # visibly applies to subtotal + shipping (the welcome coupon is whole-order).
  test "with a discount inserts the discount line after shipping, before vat" do
    @cart.discount_rate = 0.10
    kinds = CartSummary.lines(@cart).map { |l| l[:kind] }
    assert_equal %i[subtotal shipping discount vat total], kinds
  end

  test "shows the discount as a negative GBP amount and flags it negative" do
    @cart.discount_rate = 0.10
    discount = CartSummary.lines(@cart).find { |l| l[:kind] == :discount }
    # 10% of (20 + 6.99) = 2.699 -> -£2.70.
    assert_equal "-£2.70", discount[:amount]
    assert_equal true, discount[:negative]
  end

  # The cart labels the discount with the percentage (it has no Stripe code at
  # preview time), unlike OrderSummary which uses the recorded code.
  test "labels the discount with the welcome percentage" do
    @cart.discount_rate = 0.10
    discount = CartSummary.lines(@cart).find { |l| l[:kind] == :discount }
    assert_equal "Discount (#{CartsHelper::WELCOME_DISCOUNT_PERCENTAGE}%)", discount[:label]
  end

  # A samples-only cart takes no discount (matching SessionBuilder/Cart), so the
  # line is omitted even when a rate was injected.
  test "omits the discount line for a samples-only cart even with a rate" do
    samples_cart = Cart.create!
    samples_cart.cart_items.create!(product: products(:sample_cup_8oz), quantity: 1, price: 0, is_sample: true)
    samples_cart.discount_rate = 0.10

    kinds = CartSummary.lines(samples_cart).map { |l| l[:kind] }
    assert_not_includes kinds, :discount
  end

  test "flags only the discount line as negative" do
    @cart.discount_rate = 0.10
    non_discount = CartSummary.lines(@cart).reject { |l| l[:kind] == :discount }
    assert non_discount.none? { |l| l[:negative] }, "only the discount line should be negative"
  end
end
