require "test_helper"

class OnsiteCheckoutTest < ActiveSupport::TestCase
  test "disabled when ONSITE_CHECKOUT is unset" do
    ENV.stubs(:[]).with("ONSITE_CHECKOUT").returns(nil)
    assert_not OnsiteCheckout.enabled?
  end

  test "enabled for truthy values" do
    %w[true 1].each do |value|
      ENV.stubs(:[]).with("ONSITE_CHECKOUT").returns(value)
      assert OnsiteCheckout.enabled?, "expected #{value.inspect} to enable"
    end
  end

  test "disabled for falsy or junk values" do
    [ "false", "0", "", "banana" ].each do |value|
      ENV.stubs(:[]).with("ONSITE_CHECKOUT").returns(value)
      assert_not OnsiteCheckout.enabled?, "expected #{value.inspect} to disable"
    end
  end
end
