require "test_helper"

class GamePromoCodesControllerTest < ActionDispatch::IntegrationTest
  # Mirrors Game::StackReplay's geometry for a 400px canvas
  CANVAS = 400
  START_X = 108

  setup do
    LeaderboardEntry.delete_all
    GameLead.delete_all
    Stripe::Coupon.stubs(:retrieve).returns(stub(id: "afida-stack-win"))
  end

  def token(issued_at: 5.minutes.ago)
    Game::VerifiedRun.token_verifier.generate({ "issued_at" => issued_at.to_i })
  end

  def stub_mint(code)
    Stripe::PromotionCode.stubs(:create).returns(stub(code: code))
  end

  def win_claim(overrides = {})
    { token: token, canvas_width: CANVAS, xs: [ START_X ] * 15,
      email: "cafe@example.com" }.merge(overrides)
  end

  test "a verified winning run mints a code straight into the claimant's inbox" do
    stub_mint("STACKMHR4T7")

    assert_enqueued_email_with GameMailer, :win_code, args: [ "cafe@example.com", "STACKMHR4T7" ] do
      post game_win_code_path, params: win_claim, as: :json
    end

    assert_response :success
    assert_no_match(/STACKMHR4T7/, response.body, "the code must never travel back to the client")
  end

  test "the claim captures the lead with its consent choice" do
    stub_mint("STACKMHR4T7")

    post game_win_code_path, params: win_claim(email: "Cafe@Example.com", marketing: true), as: :json

    lead = GameLead.find_by(email: "cafe@example.com")
    assert_equal "win", lead.source
    assert lead.marketing_opt_in
    assert_equal "game_win", EmailSubscription.find_by(email: "cafe@example.com").source
  end

  test "no email, no claim" do
    post game_win_code_path, params: win_claim(email: ""), as: :json

    assert_response :unprocessable_entity
    assert_equal "invalid_email", response.parsed_body["error"]
  end

  test "an implausible email is rejected before anything mints" do
    post game_win_code_path, params: win_claim(email: "not-an-email"), as: :json

    assert_response :unprocessable_entity
    assert_equal "invalid_email", response.parsed_body["error"]
    assert_equal 0, GameLead.count
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

  test "does not create a cart row for a cookieless client" do
    stub_mint("STACKMHR4T7")

    assert_no_difference "Cart.count" do
      post game_win_code_path, params: win_claim, as: :json
    end

    assert_response :success
  end

  test "a second claim the same month resends the stored code and does not mint another" do
    stub_mint("STACKMHR4T7")
    post game_win_code_path, params: win_claim, as: :json
    assert_response :success

    Stripe::PromotionCode.stubs(:create).returns(stub(code: "STACKXXXXXX"))

    assert_enqueued_email_with GameMailer, :win_code, args: [ "cafe@example.com", "STACKMHR4T7" ] do
      post game_win_code_path, params: win_claim, as: :json
    end

    assert_response :success
    assert_equal "STACKMHR4T7", GameLead.find_by(email: "cafe@example.com").win_promo_code
  end

  test "Stripe being down degrades gracefully, and no email goes out" do
    Stripe::PromotionCode.stubs(:create).raises(Stripe::APIConnectionError.new("down"))

    assert_no_enqueued_emails do
      post game_win_code_path, params: win_claim, as: :json
    end

    assert_response :service_unavailable
    assert_equal "mint_failed", response.parsed_body["error"]
  end
end
