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

  # One spelling of the seller, as registered at Companies House and printed
  # on the invoice: no comma in the name, no "Northwood" in the address.
  test "names the seller and its address as the invoice does" do
    get "/terms-conditions"

    assert_select "#company-info dd", text: CompanyDetails::LEGAL_NAME
    assert_select "#company-info dd", text: "#{CompanyDetails.postal_address}, United Kingdom"
    assert_no_match(/B&amp;B Eco, Ltd|B&B Eco, Ltd/, response.body)
    assert_no_match(/Northwood/, response.body)
  end
end
