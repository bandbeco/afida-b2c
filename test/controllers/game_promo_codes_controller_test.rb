require "test_helper"

class GamePromoCodesControllerTest < ActionDispatch::IntegrationTest
  # Mirrors Game::StackReplay's geometry for a 400px canvas
  CANVAS = 400
  START_X = 108

  setup do
    LeaderboardEntry.delete_all
    Stripe::Coupon.stubs(:retrieve).returns(stub(id: "afida-stack-win"))
  end

  def token(issued_at: 5.minutes.ago)
    GameLeaderboardController.token_verifier.generate({ "issued_at" => issued_at.to_i })
  end

  def stub_mint(code)
    Stripe::PromotionCode.stubs(:create).returns(stub(code: code))
  end

  def win_claim(overrides = {})
    { token: token, canvas_width: CANVAS, xs: [ START_X ] * 15 }.merge(overrides)
  end

  # ---------- win ----------

  test "a verified winning run mints a unique code" do
    stub_mint("STACKMHR4T7")

    post game_win_code_path, params: win_claim, as: :json

    assert_response :success
    assert_equal "STACKMHR4T7", response.parsed_body["code"]
  end

  test "fourteen stacks is below target without an invite" do
    post game_win_code_path, params: win_claim(xs: [ START_X ] * 14), as: :json

    assert_response :unprocessable_entity
    assert_equal "below_target", response.parsed_body["error"]
  end

  test "an invite link from another player lowers the target to twelve" do
    referrer = LeaderboardEntry.create!(name: "Roastery", score: 20, submitter_ip: "203.0.113.9")
    stub_mint("STACKC4NHW6")

    post game_win_code_path, params: win_claim(xs: [ START_X ] * 12, ref: referrer.ref_code), as: :json

    assert_response :success
    assert_equal "STACKC4NHW6", response.parsed_body["code"]
  end

  test "your own invite link earns no lower target" do
    mine = LeaderboardEntry.create!(name: "Me", score: 20, submitter_ip: "127.0.0.1")

    post game_win_code_path, params: win_claim(xs: [ START_X ] * 12, ref: mine.ref_code), as: :json

    assert_response :unprocessable_entity
    assert_equal "below_target", response.parsed_body["error"]
  end

  test "a bogus replay mints nothing" do
    post game_win_code_path, params: win_claim(xs: [ START_X + 179 ] + [ START_X ] * 14), as: :json

    assert_response :unprocessable_entity
    assert_equal "invalid_replay", response.parsed_body["error"]
  end

  test "a forged token mints nothing" do
    post game_win_code_path, params: win_claim(token: "forged"), as: :json

    assert_response :unprocessable_entity
    assert_equal "invalid_token", response.parsed_body["error"]
  end

  test "a run claimed faster than humanly possible mints nothing" do
    post game_win_code_path, params: win_claim(token: token(issued_at: 2.seconds.ago)), as: :json

    assert_response :unprocessable_entity
    assert_equal "too_fast", response.parsed_body["error"]
  end

  test "Stripe being down degrades gracefully" do
    Stripe::PromotionCode.stubs(:create).raises(Stripe::APIConnectionError.new("down"))

    post game_win_code_path, params: win_claim, as: :json

    assert_response :service_unavailable
    assert_equal "mint_failed", response.parsed_body["error"]
  end

  # ---------- referral ----------

  def referrer_with_verified_invite
    referrer = LeaderboardEntry.create!(name: "Roastery", score: 20, submitter_ip: "203.0.113.9")
    LeaderboardEntry.create!(name: "Invitee", score: 12, submitter_ip: "198.51.100.4", referrer: referrer)
    referrer
  end

  test "a referrer with a verified invite claims their code" do
    referrer = referrer_with_verified_invite
    stub_mint("MATEC4NHW6")

    post game_referral_code_path, params: { me: referrer.ref_code }, as: :json

    assert_response :success
    assert_equal "MATEC4NHW6", response.parsed_body["code"]
    assert_equal "MATEC4NHW6", referrer.reload.referral_promo_code
  end

  test "claiming again re-shows the stored code without minting a second one" do
    referrer = referrer_with_verified_invite
    stub_mint("MATEC4NHW6")
    post game_referral_code_path, params: { me: referrer.ref_code }, as: :json

    Stripe::PromotionCode.stubs(:create).raises(Stripe::APIConnectionError.new("would be a second mint"))
    post game_referral_code_path, params: { me: referrer.ref_code }, as: :json

    assert_response :success
    assert_equal "MATEC4NHW6", response.parsed_body["code"]
  end

  test "no verified invites, no code" do
    lonely = LeaderboardEntry.create!(name: "Solo", score: 20, submitter_ip: "203.0.113.9")

    post game_referral_code_path, params: { me: lonely.ref_code }, as: :json

    assert_response :unprocessable_entity
    assert_equal "no_verified_invites", response.parsed_body["error"]
  end

  test "self-invites from the referrer's own address count for nothing" do
    referrer = LeaderboardEntry.create!(name: "Roastery", score: 20, submitter_ip: "203.0.113.9")
    LeaderboardEntry.create!(name: "Sockpuppet", score: 12, submitter_ip: "203.0.113.9", referrer: referrer)

    post game_referral_code_path, params: { me: referrer.ref_code }, as: :json

    assert_response :unprocessable_entity
    assert_equal "no_verified_invites", response.parsed_body["error"]
  end

  test "an unknown ref code is rejected" do
    post game_referral_code_path, params: { me: "nope99" }, as: :json

    assert_response :unprocessable_entity
    assert_equal "unknown_code", response.parsed_body["error"]
  end

  # ---------- email ----------

  def stub_active_code(active)
    Stripe::PromotionCode.stubs(:list).returns(stub(data: active ? [ stub(code: "STACKMHR4T7") ] : []))
  end

  test "emails a code the player holds and captures the lead" do
    stub_active_code(true)

    assert_enqueued_emails 1 do
      post game_email_code_path, params: { email: "Cafe@Example.com", code: "STACKMHR4T7", marketing: true }, as: :json
    end

    assert_response :success
    lead = GameLead.find_by(email: "cafe@example.com")
    assert_equal "win", lead.source
    assert lead.marketing_opt_in
  end

  test "a made-up code that Stripe never minted sends nothing" do
    stub_active_code(false)

    assert_no_enqueued_emails do
      post game_email_code_path, params: { email: "cafe@example.com", code: "STACKMHR4T7" }, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "unknown_promo", response.parsed_body["error"]
    assert_equal 0, GameLead.count
  end

  test "a string that isn't even code-shaped is rejected without asking Stripe" do
    post game_email_code_path, params: { email: "cafe@example.com", code: "'; DROP TABLE" }, as: :json

    assert_response :unprocessable_entity
    assert_equal "invalid_code", response.parsed_body["error"]
  end

  test "an implausible email is rejected" do
    post game_email_code_path, params: { email: "not-an-email", code: "STACKMHR4T7" }, as: :json

    assert_response :unprocessable_entity
    assert_equal "invalid_email", response.parsed_body["error"]
  end
end
