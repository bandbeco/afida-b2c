require "test_helper"

# OrderAddress is the single source of truth for the address lines every order
# surface renders (storefront pages, admin page, ops email, PDF), mirroring
# OrderSummary's role for the money lines. Each line is {kind:, text:}: kind
# (:name/:address/:note) is the one contract surfaces style against, so "the
# first line is the name" is never inferred from position - a nil name simply
# has no :name line, and the same-as-delivery note is never styled as a name.
class OrderAddressTest < ActiveSupport::TestCase
  setup do
    @order = orders(:one)
  end

  test "shipping_lines returns the shipping address as kinded display lines" do
    assert_equal [
      { kind: :name, text: @order.shipping_name },
      { kind: :address, text: @order.shipping_address_line1 },
      { kind: :address, text: @order.shipping_address_line2 },
      { kind: :address, text: "#{@order.shipping_city}, #{@order.shipping_postal_code}" },
      { kind: :address, text: @order.shipping_country }
    ], OrderAddress.shipping_lines(@order)
  end

  test "shipping_lines omits a blank address_line2" do
    @order.shipping_address_line2 = nil

    lines = OrderAddress.shipping_lines(@order)

    assert_equal @order.shipping_address_line1, lines[1][:text]
    assert_equal "#{@order.shipping_city}, #{@order.shipping_postal_code}", lines[2][:text]
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

    assert_equal [
      { kind: :name, text: "Accounts Payable" },
      { kind: :address, text: "1 Finance Row" },
      { kind: :address, text: "Manchester, M1 1AA" },
      { kind: :address, text: "GB" }
    ], OrderAddress.billing_lines(@order)
  end

  test "billing_lines carries no name line when Stripe returned no billing name" do
    @order.assign_attributes(
      billing_name: nil,
      billing_address_line1: "1 Finance Row",
      billing_city: "Manchester",
      billing_postal_code: "M1 1AA",
      billing_country: "GB"
    )

    lines = OrderAddress.billing_lines(@order)

    assert_equal [], lines.select { |line| line[:kind] == :name }
    assert_equal({ kind: :address, text: "1 Finance Row" }, lines.first)
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

    assert_equal [ { kind: :note, text: "Same as delivery address" } ],
      OrderAddress.billing_lines(@order)
  end
end
