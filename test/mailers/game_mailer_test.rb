require "test_helper"

class GameMailerTest < ActionMailer::TestCase
  test "win_code sends the code to the address that asked for it" do
    email = GameMailer.win_code("cafe@example.com", "STACKMHR4T7")

    assert_emails 1 do
      email.deliver_now
    end
    assert_equal [ "cafe@example.com" ], email.to
    assert_match "STACKMHR4T7", email.subject
    assert_match "STACKMHR4T7", email.body.encoded
    assert_match "afida.com", email.body.encoded
  end

  test "mate_code tells a referrer their kickback landed" do
    entry = LeaderboardEntry.create!(name: "Roastery", score: 20,
      email: "roastery@example.com", referral_promo_code: "MATEC4NHW6")

    email = GameMailer.mate_code(entry)

    assert_equal [ "roastery@example.com" ], email.to
    assert_match "MATEC4NHW6", email.body.encoded
    assert_match(/5%/, email.body.encoded)
  end

  test "dethroned nudges the outstacked leader back to the game" do
    old_leader = LeaderboardEntry.create!(name: "Roastery", score: 17, email: "roastery@example.com")
    usurper = LeaderboardEntry.create!(name: "Deli", score: 19)

    email = GameMailer.dethroned(old_leader, by: usurper)

    assert_equal [ "roastery@example.com" ], email.to
    assert_match "Deli", email.body.encoded
    assert_match "19", email.body.encoded
    assert_match "afida.com/game", email.body.encoded
  end
end
