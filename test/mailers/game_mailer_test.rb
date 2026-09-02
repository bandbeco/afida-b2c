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
    email = GameMailer.mate_code("roastery@example.com", "MATEC4NHW6")

    assert_equal [ "roastery@example.com" ], email.to
    assert_match "MATEC4NHW6", email.body.encoded
    assert_match(/10 off/, email.body.encoded)
    assert_match "someone else", email.body.encoded
    assert_no_match(/caf[eé]/i, email.body.encoded)
  end

  test "dethroned nudges the outstacked leader back to the game" do
    old_leader = LeaderboardEntry.create!(name: "Roastery", score: 17, email: "roastery@example.com")
    usurper = LeaderboardEntry.create!(name: "Deli", score: 19)

    email = GameMailer.dethroned(old_leader, by: usurper)

    assert_equal [ "roastery@example.com" ], email.to
    assert_match "Deli", email.body.encoded
    assert_match "19", email.body.encoded
    assert_match "afida.com/game", email.body.encoded
    assert_no_match(/case of cups/i, email.body.encoded)
    assert_match "shoutout", email.body.encoded
    assert_match "https://www.instagram.com/afidasupplies", email.html_part.body.to_s
    assert_match "@afidasupplies", email.html_part.body.to_s
  end
end
