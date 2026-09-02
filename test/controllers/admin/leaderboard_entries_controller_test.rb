require "test_helper"

class Admin::LeaderboardEntriesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @headers = { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }
    LeaderboardEntry.delete_all
    @entry = LeaderboardEntry.create!(name: "Laurent", score: 12, instagram_handle: "the.roastery")
  end

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }, headers: @headers
  end

  test "non-admins are turned away" do
    sign_in_as(users(:acme_member))

    get admin_leaderboard_entries_path, headers: @headers

    assert_redirected_to root_path
  end

  test "admins see the entries with their moderation state" do
    sign_in_as(users(:acme_admin))

    get admin_leaderboard_entries_path, headers: @headers

    assert_response :success
    assert_select "td", text: /Laurent/
    assert_select "td", text: /the\.roastery/
  end

  test "an admin can approve an entry" do
    sign_in_as(users(:acme_admin))

    patch approve_admin_leaderboard_entry_path(@entry), headers: @headers

    assert @entry.reload.approved?
  end

  test "an admin can reject an entry" do
    sign_in_as(users(:acme_admin))

    patch reject_admin_leaderboard_entry_path(@entry), headers: @headers

    assert @entry.reload.rejected?
  end

  test "admins see prize-claim emails that never joined the board" do
    GameLead.capture(email: "winner-only@example.com", source: "win")
    sign_in_as(users(:acme_admin))

    get admin_leaderboard_entries_path, headers: @headers

    assert_response :success
    assert_select "td", text: /winner-only@example.com/
  end

  test "the review filter shows only held entries, with their flags" do
    LeaderboardEntry.create!(name: "Clean", score: 8, status: "approved")
    @entry.update!(flags: [ "high_score" ])

    sign_in_as(users(:acme_admin))
    get admin_leaderboard_entries_path(filter: "review"), headers: @headers

    assert_response :success
    assert_select "td", text: /Laurent/
    assert_select "span", text: /high_score/
    assert_select "td", text: /Clean/, count: 0
  end
end
