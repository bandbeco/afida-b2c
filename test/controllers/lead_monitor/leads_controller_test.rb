require "test_helper"

class LeadMonitor::LeadsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @lead = LeadMonitor::Lead.create!(source: "fhrs", external_id: "1", business_name: "Review café", address: "1 High Street")
  end

  def sign_in(user = users(:acme_admin))
    post session_url, params: { email_address: user.email_address, password: "password" }
  end

  test "anonymous and non admin access is denied including mutations and export" do
    get lead_monitor_leads_path
    assert_redirected_to new_session_path
    sign_in(users(:acme_member))
    get lead_monitor_leads_path(format: :csv)
    assert_redirected_to root_path
    patch lead_monitor_lead_path(@lead), params: { lead: { contact_email: "owner@example.com" } }
    assert_redirected_to root_path
    post activity_lead_monitor_lead_path(@lead), params: { activity: { kind: "suppressed", notes: "Stop" } }
    assert_redirected_to root_path
    assert_nil @lead.reload.contact_email
    assert_empty @lead.activities
  end

  test "review queue and detail pages do not load storefront data" do
    sign_in
    Cart.expects(:find_or_create_by).never
    Category.expects(:browsable).never
    get lead_monitor_leads_path
    assert_response :success
    assert_select "a", text: "Review café"
    get lead_monitor_lead_path(@lead)
    assert_response :success
    assert_select "textarea[name='lead[evidence_notes]']"
    assert_select "textarea#outreach-template", count: 0
  end

  test "review is attributed to the authenticated admin and saved with evidence" do
    sign_in
    patch lead_monitor_lead_path(@lead), params: { lead: {
      classification: "upcoming", opening_on: Date.current + 5, evidence_kind: "direct_confirmation",
      evidence_notes: "Spoke with owner today; venue and address match", location_verified: "1",
      reviewed_by: "forged", reviewed_at: 10.years.ago, contact_phone: "01234 567890"
    } }
    assert_redirected_to lead_monitor_lead_path(@lead)
    assert_equal users(:acme_admin).email_address, @lead.reload.reviewed_by
    assert @lead.opening_eligible?
    get lead_monitor_lead_path(@lead)
    assert_select "textarea#outreach-template", count: 1
  end

  test "contact details saved with blank evidence fields do not count as a review" do
    sign_in
    patch lead_monitor_lead_path(@lead), params: { lead: {
      classification: "possible", opening_on: "", evidence_kind: "", evidence_url: "", evidence_notes: "",
      location_verified: "0", contact_phone: "01234 567890"
    } }
    assert_redirected_to lead_monitor_lead_path(@lead)
    assert_equal "01234 567890", @lead.reload.contact_phone
    assert_nil @lead.reviewed_by
    assert_nil @lead.reviewed_at
  end

  test "an activity without a kind is rejected as invalid" do
    sign_in
    post activity_lead_monitor_lead_path(@lead), params: { activity: { notes: "Hello" } }
    assert_response :unprocessable_entity
    assert_empty @lead.activities
  end

  test "invalid evidence stays on the form and cannot enable outreach" do
    sign_in
    patch lead_monitor_lead_path(@lead), params: { lead: { classification: "recent", opening_on: Date.current } }
    assert_response :unprocessable_entity
    assert_equal "possible", @lead.reload.classification
    post activity_lead_monitor_lead_path(@lead), params: { activity: { kind: "sent", notes: "Hello" } }
    assert_response :unprocessable_entity
    assert_empty @lead.activities
  end

  test "the review queue paginates fifty candidates per page and exports every row" do
    LeadMonitor::Lead.insert_all!((2..52).map { |n|
      { source: "fhrs", external_id: n.to_s, business_name: "Café #{n}", created_at: Time.current, updated_at: Time.current }
    })
    sign_in
    get lead_monitor_leads_path
    assert_select "tbody tr", 50
    assert_select "nav.pagy"
    get lead_monitor_leads_path(page: 2)
    assert_select "tbody tr", 2
    get lead_monitor_leads_path(format: :csv)
    assert_equal 53, response.body.lines.size
  end

  test "the admin sidebar and mobile dock both reach the lead monitor" do
    sign_in
    get admin_products_path
    assert_select ".drawer-side a[href=?]", lead_monitor_leads_path
    assert_select ".dock a[href=?]", lead_monitor_leads_path
  end

  test "qualification filters and CSV include classification and neutralize spreadsheet formulas" do
    @lead.update!(business_name: "=HYPERLINK(1)")
    sign_in
    get lead_monitor_leads_path(classification: "upcoming")
    assert_response :success
    assert_select "a", text: "=HYPERLINK(1)", count: 0
    get lead_monitor_leads_path(format: :csv)
    assert_response :success
    assert_includes response.body, "'=HYPERLINK(1)"
    assert_includes response.body, "possible"
    assert_includes response.body, "Opening eligible"
  end
end
