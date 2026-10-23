require "test_helper"

class PrivacyPolicyTest < ActionDispatch::IntegrationTest
  # The data controller is named as registered at Companies House, matching
  # the terms and the invoice.
  test "names the company with its registered spelling" do
    get "/privacy-policy"

    assert_response :success
    assert_select "dd", text: CompanyDetails::LEGAL_NAME
    assert_no_match(/B&amp;B Eco, Ltd|B&B Eco, Ltd/, response.body)
  end
end
