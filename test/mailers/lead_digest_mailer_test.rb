require "test_helper"

class LeadDigestMailerTest < ActionMailer::TestCase
  def section(overrides = {})
    {
      source: "fhrs",
      failed: false,
      seeded: false,
      fetched_count: 15000,
      sighted_count: 2,
      new_lead_ids: [ leads(:fhrs_cafe).id, leads(:fhrs_takeaway_contacted).id ]
    }.merge(overrides)
  end

  test "sends to the internal recipient with the new-lead count in the subject" do
    email = LeadDigestMailer.with(sections: [ section ]).weekly_digest

    assert_equal [ "laurent@curau.me" ], email.to
    assert_equal "[LeadGen] 2 new leads this week", email.subject
  end

  test "renders the leads in both HTML and text parts" do
    email = LeadDigestMailer.with(sections: [ section ]).weekly_digest

    assert_match "Fixture Coffee House", email.html_part.body.encoded
    assert_match "Fixture Kebabs", email.html_part.body.encoded
    assert_match "Fixture Coffee House", email.text_part.body.encoded
  end

  test "attaches a CSV named after the source and date" do
    email = LeadDigestMailer.with(sections: [ section ]).weekly_digest

    assert_equal 1, email.attachments.size
    attachment = email.attachments.first
    assert_equal "fhrs-new-leads-#{Date.current.iso8601}.csv", attachment.filename
    assert_match "text/csv", attachment.content_type
    assert_match "Fixture Coffee House", attachment.body.encoded
  end

  test "a seeded run reports the seed count and attaches no CSV" do
    email = LeadDigestMailer.with(sections: [ section(seeded: true, sighted_count: 14800, new_lead_ids: []) ])
                            .weekly_digest

    assert_equal "[LeadGen] 0 new leads this week", email.subject
    assert_match "seeded 14,800 register entries", email.html_part.body.encoded
    assert_empty email.attachments
  end

  test "a failed run sends a FAILED subject and a warning body" do
    email = LeadDigestMailer.with(sections: [ { source: "fhrs", failed: true } ]).weekly_digest

    assert_equal "[LeadGen] weekly run FAILED", email.subject
    assert_match "fetch failed", email.html_part.body.encoded.downcase
    assert_match "fetch failed", email.text_part.body.encoded.downcase
    assert_empty email.attachments
  end

  test "a CSV generation failure still delivers the email without the attachment" do
    LeadGen::LeadsCsv.stubs(:generate).raises(StandardError, "boom")

    email = LeadDigestMailer.with(sections: [ section ]).weekly_digest

    assert_emails 1 do
      email.deliver_now
    end
    assert_empty email.attachments
    assert_match "Fixture Coffee House", email.html_part.body.encoded
  end

  test "the HTML table is capped with an overflow note pointing at the CSV" do
    rows = (1..105).map do |i|
      { source: "fhrs", external_id: "888#{format('%03d', i)}", business_name: "Bulk Cafe #{i}",
        payload: {} }
    end
    ids = Lead.insert_all(rows, record_timestamps: true, returning: [ :id ]).rows.flatten

    email = LeadDigestMailer.with(sections: [ section(sighted_count: 105, new_lead_ids: ids) ]).weekly_digest

    assert_match "plus 5 more in the attached CSV", email.html_part.body.encoded
  end
end
