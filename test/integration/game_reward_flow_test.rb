require "test_helper"

class GameRewardFlowTest < ActionDispatch::IntegrationTest
  def boot(ref: nil)
    get game_path, params: { ref: ref }.compact
    JSON.parse(css_select("#game-board").text)
  end

  def run_params(board, score: 15)
    { token: board.fetch("token"), canvas_width: 420, xs: [ 113.4 ] * score }
  end

  test "invalid referrals do not promise a lower target" do
    assert_equal 15, boot(ref: "unknown").fetch("effective_win_score")
  end

  test "two participants sharing an IP can invite each other but cannot own each other's entry" do
    host = GameParticipant.create!(email: "host@example.com")
    entry = LeaderboardEntry.create!(name: "Host", score: 20, game_participant: host,
      submitter_ip: "127.0.0.1", status: "approved")
    board = boot(ref: host.ref_code)
    assert_equal 12, board.fetch("effective_win_score")
    Game::PromoCodes.stubs(:mint).returns("STACKTEST12")
    travel 1.minute do
      post game_win_code_path, params: run_params(board, score: 12).merge(email: "guest@example.com"), as: :json
    end
    assert_response :success
    assert_equal "host@example.com", host.reload.email
    assert_nil entry.reload.email
    assert response.parsed_body.fetch("share_url").include?("ref=")
  end

  test "a page token cannot be spent from a different participant session" do
    board = boot
    other = open_session
    travel 1.minute do
      other.post game_win_code_path, params: run_params(board).merge(email: "guest@example.com"), as: :json
    end
    assert_equal 422, other.response.status
    assert_equal "invalid_token", other.response.parsed_body["error"]
  end

  test "claiming without joining the board creates a stable gift link" do
    board = boot
    Game::PromoCodes.stubs(:mint).returns("STACKTEST12")
    travel 1.minute do
      post game_win_code_path, params: run_params(board).merge(email: "guest@example.com"), as: :json
    end
    assert_response :success
    link = response.parsed_body.fetch("share_url")
    assert_equal 0, LeaderboardEntry.where(name: "guest").count
    assert_equal link, boot.fetch("share_url")
  end

  test "pending names never appear on the public board or dethrone an approved leader" do
    LeaderboardEntry.create!(name: "Leader", score: 10, status: "approved", email: "leader@example.com")
    board = boot
    travel 1.minute do
      assert_no_enqueued_emails do
        post game_leaderboard_path, params: run_params(board).merge(name: "afida admin"), as: :json
      end
    end
    assert_response :created
    assert_equal "pending", response.parsed_body["status"]
    get game_leaderboard_path
    assert_not_includes response.parsed_body["entries"].map { |e| e["name"] }, "afida admin"
  end

  test "the game offers readable terms and explicit form labels" do
    boot
    assert_select "meta[name=viewport][content*='user-scalable=no']", count: 0
    assert_select "label[for=winEmail]"
    assert_select "label[for=boardName]"
    assert_select "#menu", text: /£100.*excl\. VAT/m
    assert_select "#claimBtn"
    assert_select "a[href='/shop']"
  end
end
