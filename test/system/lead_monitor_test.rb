require "application_system_test_case"

class LeadMonitorTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
  end

  test "an admin reviews a candidate and records a manual contact then a reply" do
    lead = LeadMonitor::Lead.create!(source: "fhrs", external_id: "browser-1",
      business_name: "New location café", address: "1 High Street", postcode: "SW1A 1AA")

    visit new_session_path
    fill_in "Email", with: users(:acme_admin).email_address
    fill_in "Password", with: "password"
    click_button "Sign In"
    assert_no_current_path new_session_path
    visit lead_monitor_leads_path
    click_on "New location café"
    assert_text "verification required before contact"
    assert_no_selector "#outreach-template"

    select "Opening soon", from: "Classification"
    fill_in "lead_opening_on", with: (Date.current + 10).iso8601
    select "Direct confirmation", from: "Evidence kind"
    fill_in "lead_evidence_notes", with: "Owner confirmed today's review refers to 1 High Street and the planned date."
    check "I verified that this evidence refers to this venue and address"
    fill_in "Contact email", with: "owner@example.com"
    click_on "Save review and contact details"
    assert_text "Review saved."
    assert_selector "#outreach-template"

    select "Initial message sent", from: "Activity"
    fill_in "Message / channel / reply notes", with: "Personal kit invitation sent by email."
    click_on "Record activity"
    assert_text "Status: Contacted"
    assert_text "Personal kit invitation sent by email."

    select "Reply received", from: "Activity"
    fill_in "Message / channel / reply notes", with: "Owner would like samples."
    click_on "Record activity"
    assert_text "Status: Replied"
    assert_no_selector "#outreach-template"
    assert_equal "upcoming", lead.reload.classification
  end
end
