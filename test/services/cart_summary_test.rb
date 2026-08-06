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
    # A known mainland destination, because most of these tests are about the
    # line shape and money format, which need shipping to be QUOTED at all: the
    # cart defers it until the customer says where the order is going. The
    # deferral has its own tests below, which use a cart with no postcode.
    @cart.delivery_postcode = "WD18 9SB"
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
    @cart.delivery_postcode = "WD18 9SB" # a known destination, so shipping is quoted
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
  #
  # But "Free" is a MAINLAND promise, so it may only be shown once we know the
  # destination. Cart#delivery_zone falls back to mainland when no postcode has
  # been given, which prices the cart but must not be reported to the customer
  # as a quote: the drawer was showing "Shipping Free" on a cart bound for an
  # unknown address, which is the same unqualified claim the free-delivery copy
  # had to be corrected for.
  test "shows free shipping as Free once the destination is known to be mainland" do
    free_cart = free_shipping_cart
    free_cart.delivery_postcode = "WD18 9SB"

    shipping = CartSummary.lines(free_cart).find { |l| l[:kind] == :shipping }
    assert_equal "Free", shipping[:amount]
  end

  test "defers the shipping line until a destination is known" do
    # The wording points at the postcode field, which both cart surfaces now
    # carry, rather than deferring to checkout: the customer can resolve this
    # here and now, and saying "at checkout" would send them looking for a step
    # that no longer holds the answer.
    free_cart = free_shipping_cart # no postcode: free_shipping_cart sets none

    shipping = CartSummary.lines(free_cart).find { |l| l[:kind] == :shipping }
    assert_equal "Enter postcode", shipping[:amount],
                 "a cart with no postcode must not be quoted a mainland price"
  end

  test "defers the shipping line on a charged cart with no destination" do
    # Below the threshold the unqualified figure is £6.99, which is equally a
    # mainland-only price: off-mainland is dearer, so quoting it before we know
    # the destination understates the cost.
    charged = Cart.create!
    charged.cart_items.create!(product: products(:one), quantity: 2, price: 10.00)

    shipping = CartSummary.lines(charged).find { |l| l[:kind] == :shipping }

    assert_equal "Enter postcode", shipping[:amount]
  end

  test "quotes the off-mainland rate once an off-mainland destination is known" do
    @cart.delivery_postcode = "IV51 9YB"

    shipping = CartSummary.lines(@cart).find { |l| l[:kind] == :shipping }
    assert_equal ActiveSupport::NumberHelper.number_to_currency(
      Shipping.cost_for_zone_in_pounds(:highlands)
    ), shipping[:amount]
  end

  test "a large off-mainland cart is never shown as Free" do
    # The live bug in miniature: a £449 order to Skye shipped free. The summary
    # must not display the mainland promise for a destination that never had it.
    free_cart = free_shipping_cart
    free_cart.delivery_postcode = "IV51 9YB"

    shipping = CartSummary.lines(free_cart).find { |l| l[:kind] == :shipping }
    assert_not_equal "Free", shipping[:amount]
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

  # The on-site checkout page asks for a placeholder so a promo code applied
  # on-page has a discount row to unhide; the cart surfaces never pass the
  # option and keep their line set unchanged.
  test "placeholder_discount emits a placeholder discount row when no discount is taken" do
    lines = CartSummary.lines(@cart, placeholder_discount: true)

    assert_equal %i[subtotal shipping discount vat total], lines.map { |l| l[:kind] }
    discount = lines.find { |l| l[:kind] == :discount }
    assert discount[:placeholder]
  end

  test "placeholder_discount leaves a real discount line as is" do
    @cart.discount_rate = 0.10

    discount = CartSummary.lines(@cart, placeholder_discount: true).find { |l| l[:kind] == :discount }

    assert_not discount[:placeholder]
    assert_equal "Discount (#{CartsHelper::WELCOME_DISCOUNT_PERCENTAGE}%)", discount[:label]
  end

  private

  # A cart whose subtotal clears the free-shipping threshold, so mainland ships
  # free and every off-mainland zone still charges.
  def free_shipping_cart
    cart = Cart.create!
    product = Product.create!(
      category: categories(:cups),
      name: "Free-ship pack",
      sku: "TEST-CARTSUMMARY-FREE-SHIP",
      price: Shipping::FREE_SHIPPING_THRESHOLD,
      pac_size: 1,
      active: true
    )
    cart.cart_items.create!(product: product, quantity: 1, price: product.price)
    cart
  end
end
