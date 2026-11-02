require "test_helper"

class Checkout::StripeLinePricingTest < ActiveSupport::TestCase
  test "two packs of a pack-priced product are one stripe unit at the rounded line total" do
    pricing = pricing_for(products(:paper_lid_80mm), quantity: 2, price: "80.99")

    assert_not pricing.unit_priced?
    assert_equal 1, pricing.quantity
    assert_equal 16_198, pricing.unit_amount
    assert_equal 16_198, pricing.amount_pence
  end

  test "a configured item is one stripe unit with the unit count folded into the amount" do
    item = Cart.create!.cart_items.build(
      product: products(:branded_template_variant),
      quantity: 5000,
      price: BigDecimal("0.20"),
      configuration: { size: "12oz", quantity: 5000 },
      calculated_price: 1000.00
    )
    item.design.attach(
      io: StringIO.new("fake design content"),
      filename: "design.pdf",
      content_type: "application/pdf"
    )
    item.save!

    pricing = Checkout::StripeLinePricing.for(item)

    assert_equal 1, pricing.quantity
    assert_equal 100_000, pricing.unit_amount
    assert_equal 100_000, pricing.amount_pence
  end

  test "a sample is one stripe unit at zero regardless of cart quantity" do
    pricing = pricing_for(products(:sample_cup_8oz), quantity: 2, price: "0", is_sample: true)

    assert_equal 1, pricing.quantity
    assert_equal 0, pricing.unit_amount
    assert_equal 0, pricing.amount_pence
  end

  test "a unit-priced item keeps its quantity and rounds the unit price once" do
    product = products(:only_product_in_category)
    assert product.pac_size.blank?

    pricing = pricing_for(product, quantity: 4, price: "2.50")

    assert pricing.unit_priced?
    assert_equal 4, pricing.quantity
    assert_equal 250, pricing.unit_amount
    assert_equal 1000, pricing.amount_pence
  end

  test "sub-penny pack prices round per line" do
    pricing = pricing_for(products(:one), quantity: 1, price: "0.3333")

    assert_equal 1, pricing.quantity
    assert_equal 33, pricing.amount_pence
  end

  test "a pac_size of zero is unit priced" do
    product = products(:one)
    product.update!(pac_size: 0)

    pricing = pricing_for(product, quantity: 3, price: "1.00")

    assert pricing.unit_priced?
    assert_equal 3, pricing.quantity
    assert_equal 100, pricing.unit_amount
    assert_equal 300, pricing.amount_pence
  end

  private

  def pricing_for(product, **attrs)
    Checkout::StripeLinePricing.for(cart_item(product, **attrs))
  end

  def cart_item(product, **attrs)
    cart = Cart.create!
    cart.cart_items.create!(product: product, **attrs)
  end
end
