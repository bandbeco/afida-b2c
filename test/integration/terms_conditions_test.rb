require "test_helper"

# The terms state the seller's legal identity and how prices relate to VAT;
# both must match what the invoice, the cart and the price list say.
class TermsConditionsTest < ActionDispatch::IntegrationTest
  test "states that prices exclude VAT, at the configured rate" do
    get "/terms-conditions"

    assert_response :success
    assert_match(/prices are displayed in British Pounds \(GBP\) and exclude VAT, which is charged at #{VAT_RATE_PERCENT}%/, response.body)
    assert_no_match(/include VAT/, response.body)
  end
end
