require "test_helper"

class GameLeaderboardControllerTest < ActionDispatch::IntegrationTest
  # Mirrors Game::StackReplay's geometry for a 400px canvas
  CANVAS = 400
  START_X = 108

  def setup
    LeaderboardEntry.delete_all
  end

  def token(issued_at: 30.seconds.ago)
    GameLeaderboardController.token_verifier.generate({ "issued_at" => issued_at.to_i })
  end

  # All-perfect but short: runs under 20 drops never trip the perfect_run flag.
  def perfectish_run(n)
    [ START_X ] * n
  end

  def valid_submission(overrides = {})
    {
      token: token,
      name: "Laurent",
      instagram_handle: "@the.roastery",
      canvas_width: CANVAS,
      xs: [ START_X ] * 5
    }.merge(overrides)
  end

  # ---------- index ----------

  test "index returns the monthly board and a submission token" do
    LeaderboardEntry.create!(name: "Approved", score: 20, instagram_handle: "cafe", status: "approved")
    LeaderboardEntry.create!(name: "Pending", score: 15, instagram_handle: "hidden", status: "pending")
    LeaderboardEntry.create!(name: "Cheat", score: 90, status: "rejected")

    get game_leaderboard_path

    assert_response :success
    body = response.parsed_body
    assert body["token"].present?
    assert body["month"].present?

    names = body["entries"].map { |e| e["name"] }
    assert_includes names, "Approved"
    assert_includes names, "Pending"
    assert_not_includes names, "Cheat"

    approved = body["entries"].find { |e| e["name"] == "Approved" }
    pending_entry = body["entries"].find { |e| e["name"] == "Pending" }
    assert_equal "cafe", approved["instagram_handle"]
    assert_nil pending_entry["instagram_handle"]
    assert_equal 1, approved["rank"]
  end

  # ---------- create ----------

  test "a clean submission is approved on the spot, handle live" do
    assert_difference "LeaderboardEntry.count", 1 do
      post game_leaderboard_path, params: valid_submission(xs: perfectish_run(7)), as: :json
    end

    assert_response :created
    entry = LeaderboardEntry.last
    assert_equal 7, entry.score
    assert_equal "Laurent", entry.name
    assert_equal "the.roastery", entry.instagram_handle
    assert entry.approved?
    assert_empty entry.flags
    assert_equal "the.roastery", entry.public_handle
    assert_equal 1, response.parsed_body["rank"]
  end

  test "a suspicious submission is held for review with its reasons recorded" do
    post game_leaderboard_path, params: valid_submission(name: "afida staff", xs: perfectish_run(7)), as: :json

    assert_response :created
    entry = LeaderboardEntry.last
    assert entry.pending?
    assert_includes entry.flags, "impersonation"
    assert_nil entry.public_handle
  end

  test "an inhuman all-perfect marathon is held for review" do
    post game_leaderboard_path,
      params: valid_submission(token: token(issued_at: 2.minutes.ago), xs: [ START_X ] * 25),
      as: :json

    assert_response :created
    entry = LeaderboardEntry.last
    assert entry.pending?
    assert_includes entry.flags, "perfect_run"
  end

  test "a burst of entries from one address is held for review" do
    5.times { LeaderboardEntry.create!(name: "Laurent", score: 3, submitter_ip: "127.0.0.1") }

    post game_leaderboard_path, params: valid_submission(xs: perfectish_run(4)), as: :json

    assert_response :created
    entry = LeaderboardEntry.last
    assert entry.pending?
    assert_includes entry.flags, "burst"
  end

  test "the kill switch reverts to hold-everything moderation" do
    GameLeaderboardController.any_instance.stubs(:auto_approve?).returns(false)

    post game_leaderboard_path, params: valid_submission(xs: perfectish_run(4)), as: :json

    assert_response :created
    assert LeaderboardEntry.last.pending?
    assert_empty LeaderboardEntry.last.flags
  end

  test "the score comes from the replay, not from a score param" do
    post game_leaderboard_path, params: valid_submission(score: 9999, xs: [ START_X ] * 3), as: :json

    assert_response :created
    assert_equal 3, LeaderboardEntry.last.score
  end

  test "an impossible drop sequence is rejected" do
    assert_no_difference "LeaderboardEntry.count" do
      post game_leaderboard_path, params: valid_submission(xs: [ START_X + 179 ]), as: :json
    end

    assert_response :unprocessable_entity
  end

  test "a missing or garbage token is rejected" do
    assert_no_difference "LeaderboardEntry.count" do
      post game_leaderboard_path, params: valid_submission(token: "forged"), as: :json
      post game_leaderboard_path, params: valid_submission.except(:token), as: :json
    end

    assert_response :unprocessable_entity
  end

  test "a submission faster than humanly playable is rejected" do
    assert_no_difference "LeaderboardEntry.count" do
      post game_leaderboard_path,
        params: valid_submission(token: token(issued_at: 1.second.ago), xs: [ START_X ] * 20),
        as: :json
    end

    assert_response :unprocessable_entity
  end

  test "a stale token is rejected" do
    assert_no_difference "LeaderboardEntry.count" do
      post game_leaderboard_path, params: valid_submission(token: token(issued_at: 7.hours.ago)), as: :json
    end

    assert_response :unprocessable_entity
  end

  test "an invalid name is rejected" do
    assert_no_difference "LeaderboardEntry.count" do
      post game_leaderboard_path, params: valid_submission(name: "x" * 40), as: :json
    end

    assert_response :unprocessable_entity
  end

  test "a submission returns the entry's referral code" do
    post game_leaderboard_path, params: valid_submission(xs: perfectish_run(4)), as: :json

    assert_response :created
    assert_equal LeaderboardEntry.last.ref_code, response.parsed_body["ref_code"]
  end

  test "playing through a referral link credits the referrer" do
    referrer = LeaderboardEntry.create!(name: "Host", score: 9, submitter_ip: "9.9.9.9")

    post game_leaderboard_path, params: valid_submission(ref: referrer.ref_code, xs: perfectish_run(4)), as: :json

    assert_response :created
    assert_equal referrer, LeaderboardEntry.last.referrer
  end

  test "a referral from the referrer's own address is not credited" do
    referrer = LeaderboardEntry.create!(name: "Host", score: 9, submitter_ip: "127.0.0.1")

    post game_leaderboard_path, params: valid_submission(ref: referrer.ref_code, xs: perfectish_run(4)), as: :json

    assert_response :created
    assert_nil LeaderboardEntry.last.referrer
  end

  test "an unknown referral code is ignored" do
    post game_leaderboard_path, params: valid_submission(ref: "nosuch", xs: perfectish_run(4)), as: :json

    assert_response :created
    assert_nil LeaderboardEntry.last.referrer
  end

  test "the board reports invite progress for a returning player" do
    mine = LeaderboardEntry.create!(name: "Me", score: 9, submitter_ip: "9.9.9.9")
    LeaderboardEntry.create!(name: "Guest", score: 4, referrer: mine, submitter_ip: "2.2.2.2")

    get game_leaderboard_path(me: mine.ref_code)

    assert_response :success
    assert_equal 1, response.parsed_body.dig("me", "referrals")
    assert_equal mine.ref_code, response.parsed_body.dig("me", "ref_code")
  end

  test "rank counts only better visible scores this month" do
    LeaderboardEntry.create!(name: "Top", score: 50, status: "approved")
    LeaderboardEntry.create!(name: "Cheat", score: 60, status: "rejected")
    LeaderboardEntry.create!(name: "Old", score: 70, month: 1.month.ago.to_date.beginning_of_month)

    post game_leaderboard_path, params: valid_submission(xs: [ START_X ] * 5), as: :json

    assert_response :created
    assert_equal 2, response.parsed_body["rank"]
  end
end
