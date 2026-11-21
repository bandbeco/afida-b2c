require "test_helper"

class StripeInitializerTest < ActiveSupport::TestCase
  test "pins the endive API version above the basil shipping-details floor" do
    assert_equal "2026-10-28.endive", Stripe.api_version
    assert_operator Stripe.api_version.split(".").first, :>=, "2025-03-31"
  end
end
