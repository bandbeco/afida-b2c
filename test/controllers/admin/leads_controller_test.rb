require "test_helper"

class Admin::LeadsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @headers = { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" }
    @lead = leads(:fhrs_cafe)
    @admin = users(:acme_admin)
    sign_in_as(@admin)
  end

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }, headers: @headers
  end

  test "index lists leads" do
    get admin_leads_path, headers: @headers

    assert_response :success
    assert_match "Fixture Coffee House", response.body
    assert_match "Fixture Kebabs", response.body
  end

  test "index filters by status" do
    get admin_leads_path(status: "contacted"), headers: @headers

    assert_response :success
    assert_match "Fixture Kebabs", response.body
    assert_no_match "Fixture Coffee House", response.body
  end

  test "index ignores an unknown status filter" do
    get admin_leads_path(status: "bogus"), headers: @headers

    assert_response :success
    assert_match "Fixture Coffee House", response.body
    assert_match "Fixture Kebabs", response.body
  end

  test "update_status changes the lead's status" do
    patch update_status_admin_lead_path(@lead), params: { status: "contacted" }, headers: @headers

    assert_redirected_to admin_leads_path
    assert_equal "contacted", @lead.reload.status
  end

  test "update_status rejects an unknown status" do
    patch update_status_admin_lead_path(@lead), params: { status: "garbage" }, headers: @headers

    assert_redirected_to admin_leads_path
    assert_equal "new_lead", @lead.reload.status
  end

  test "requires authentication" do
    delete session_url, headers: @headers

    get admin_leads_path, headers: @headers
    assert_redirected_to new_session_path
  end

  test "requires admin role" do
    sign_in_as(users(:acme_member))

    get admin_leads_path, headers: @headers
    assert_redirected_to root_path
  end
end
