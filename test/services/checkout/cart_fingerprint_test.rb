require "test_helper"

class Checkout::CartFingerprintTest < ActiveSupport::TestCase
  setup do
    @cart = Cart.create!
    @cart.cart_items.create!(product: products(:one), quantity: 2, price: 10.00)
  end

  def digest(cart: @cart, postcode: "WD18 9SB", discount_code: nil)
    Checkout::CartFingerprint.digest(cart: cart, postcode: postcode, discount_code: discount_code)
  end

  test "stable for identical inputs" do
    assert_equal digest, digest
  end

  test "changes when a quantity changes" do
    before = digest
    @cart.cart_items.first.update!(quantity: 3)
    assert_not_equal before, digest
  end

  test "changes when an item is added" do
    before = digest
    @cart.cart_items.create!(product: products(:two), quantity: 1, price: 30.00)
    assert_not_equal before, digest
  end

  test "changes when the postcode changes" do
    assert_not_equal digest(postcode: "WD18 9SB"), digest(postcode: "IV51 9XX")
  end

  test "insensitive to postcode case and whitespace" do
    assert_equal digest(postcode: "WD18 9SB"), digest(postcode: " wd18 9sb ")
  end

  test "changes when the discount code changes" do
    assert_not_equal digest(discount_code: nil), digest(discount_code: "coupon_abc")
  end
end
