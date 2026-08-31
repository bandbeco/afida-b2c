require "test_helper"

class GameMateCodeJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper
  def referrer(email: "roastery@example.com", code: nil)
    entry = LeaderboardEntry.create!(name: "Roastery", score: 20,
      submitter_ip: "203.0.113.9", email: email, referral_promo_code: code)
    LeaderboardEntry.create!(name: "Invitee", score: 12, submitter_ip: "198.51.100.4", referrer: entry)
    entry
  end

  test "mints, stores and emails the code when a verified invite lands" do
    entry = referrer
    Stripe::Coupon.stubs(:retrieve).returns(stub(id: "afida-stack-mate"))
    Stripe::PromotionCode.stubs(:create).returns(stub(code: "MATEC4NHW6"))

    assert_enqueued_emails 1 do
      GameMateCodeJob.perform_now(entry.id)
    end
    assert_equal "MATEC4NHW6", entry.reload.referral_promo_code
  end

  test "does nothing for a referrer who left no email" do
    entry = referrer(email: nil)

    assert_no_enqueued_emails do
      GameMateCodeJob.perform_now(entry.id)
    end
    assert_nil entry.reload.referral_promo_code
  end

  test "emails once: a code claimed or sent already is never re-sent" do
    entry = referrer(code: "MATEC4NHW6")

    assert_no_enqueued_emails do
      GameMateCodeJob.perform_now(entry.id)
    end
  end

  test "shrugs off a deleted entry" do
    assert_nothing_raised do
      GameMateCodeJob.perform_now(-1)
    end
  end
end
