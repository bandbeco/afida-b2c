require "test_helper"

# OrderAddress is the single source of truth for the address lines every order
# surface renders (storefront pages, admin page, ops email, PDF), mirroring
# OrderSummary's role for the money lines.
class OrderAddressTest < ActiveSupport::TestCase
  setup do
    @order = orders(:one)
  end

  test "shipping_lines returns the shipping address as ordered display lines" do
    assert_equal [
      @order.shipping_name,
      @order.shipping_address_line1,
      @order.shipping_address_line2,
      "#{@order.shipping_city}, #{@order.shipping_postal_code}",
      @order.shipping_country
    ], OrderAddress.shipping_lines(@order)
  end

  test "shipping_lines omits a blank address_line2" do
    @order.shipping_address_line2 = nil

    lines = OrderAddress.shipping_lines(@order)

    assert_not_includes lines, nil
    assert_equal @order.shipping_address_line1, lines[1]
    assert_equal "#{@order.shipping_city}, #{@order.shipping_postal_code}", lines[2]
  end

  test "billing_lines is empty when the order has no billing address" do
    assert_equal [], OrderAddress.billing_lines(@order)
  end

  test "billing_lines returns the billing address when it differs from shipping" do
    @order.assign_attributes(
      billing_name: "Accounts Payable",
      billing_address_line1: "1 Finance Row",
      billing_city: "Manchester",
      billing_postal_code: "M1 1AA",
      billing_country: "GB"
    )

    assert_equal [ "Accounts Payable", "1 Finance Row", "Manchester, M1 1AA", "GB" ],
      OrderAddress.billing_lines(@order)
  end

  test "billing_lines returns a same-as-delivery note when billing matches shipping" do
    @order.assign_attributes(
      billing_name: @order.shipping_name,
      billing_address_line1: @order.shipping_address_line1,
      billing_address_line2: @order.shipping_address_line2,
      billing_city: @order.shipping_city,
      billing_postal_code: @order.shipping_postal_code,
      billing_country: @order.shipping_country
    )

    assert_equal [ "Same as delivery address" ], OrderAddress.billing_lines(@order)
  end
end
