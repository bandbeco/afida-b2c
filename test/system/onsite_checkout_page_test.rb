require "application_system_test_case"

class OnsiteCheckoutPageTest < ApplicationSystemTestCase
  include StripeTestHelper

  setup do
    OnsiteCheckout.stubs(:enabled?).returns(true)
    stub_stripe_tax_rate_list
    Stripe::Checkout::Session.stubs(:create).returns(build_custom_stripe_session)
  end

  # Per the spec: assert the page renders with summary, mount points, and promo
  # control. Driving the real Stripe iframe in CI is flaky by design, so
  # confirm-and-pay is covered manually on staging, not here.
  test "checkout page renders summary, mount points, and promo control" do
    visit product_path(products(:one).slug)
    click_on "Add to Cart", match: :first

    visit cart_path
    click_on "Proceed to Checkout"

    assert_current_path checkout_path
    assert_selector "#checkout_summary"
    # The element mounts are empty placeholder divs until Stripe.js fills them
    # (it can't init against the stubbed secret here), so match invisible too.
    assert_selector "[data-onsite-checkout-target='payment']", visible: :all
    assert_selector "[data-onsite-checkout-target='address']", visible: :all
    assert_selector "[data-onsite-checkout-target='promoSection']"
    assert_selector "[data-onsite-checkout-target='payButton']"
    assert_link "Back to basket"
  end
end
