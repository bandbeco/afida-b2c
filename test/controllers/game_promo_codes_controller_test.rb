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

    assert_enqueued_email_with GameMailer, :win_code, args: [ "cafe@example.com", "STACKMHR4T7", false ] do
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

  test "a win claim attaches its email to this address's latest board entry" do
    mine = LeaderboardEntry.create!(name: "Me", score: 20, submitter_ip: "127.0.0.1")
    stub_mint("STACKMHR4T7")

    post game_win_code_path, params: win_claim, as: :json

    assert_response :success
    assert_equal "cafe@example.com", mine.reload.email
  end

  test "a public share code is not proof of ownership of a board entry" do
    host = LeaderboardEntry.create!(name: "Host", score: 20, submitter_ip: "9.9.9.9")
    stub_mint("STACKMHR4T7")

    post game_win_code_path, params: win_claim(my_ref: host.ref_code), as: :json

    assert_response :success
    assert_nil host.reload.email
  end

  test "an invite link from another player lowers the target to twelve" do
    referrer = LeaderboardEntry.create!(name: "Roastery", score: 20, submitter_ip: "203.0.113.9")
    stub_mint("STACKC4NHW6")

    post game_win_code_path, params: win_claim(xs: [ START_X ] * 12, ref: referrer.ref_code), as: :json

    assert_response :success
    assert_equal referrer, GameLead.find_by(email: "cafe@example.com").referrer
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

    assert_enqueued_email_with GameMailer, :win_code, args: [ "cafe@example.com", "STACKMHR4T7", true ] do
      post game_win_code_path, params: win_claim, as: :json
    end
    assert_equal true, response.parsed_body["resent"]

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

  test "a first claim tells the client the code is new" do
    stub_mint("STACKMHR4T7")

    post game_win_code_path, params: win_claim, as: :json

    assert_response :success
    assert_equal false, response.parsed_body["resent"]
  end

  # Every refusal used to come back as a bare 422 the page rendered as "Try again",
  # leaving no trace server-side either. The reason now rides the response and a
  # business event, so a player is told what happened and the logs show it.
  test "a rejected claim says why, with the replayed score, and reports it" do
    assert_event_reported("game.win_claim_rejected", payload: { reason: "below_target", score: 14 }) do
      post game_win_code_path, params: win_claim(xs: [ START_X ] * 14), as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "below_target", response.parsed_body["error"]
    assert_equal 14, response.parsed_body["score"]
  end

  test "a claim rejected before replay reports the reason without a score" do
    assert_event_reported("game.win_claim_rejected", payload: { reason: "invalid_token" }) do
      post game_win_code_path, params: win_claim(token: "forged"), as: :json
    end

    assert_nil response.parsed_body["score"]
  end

  test "a failed mint is reported as a rejection too" do
    Stripe::PromotionCode.stubs(:create).raises(Stripe::APIConnectionError.new("down"))

    assert_event_reported("game.win_claim_rejected", payload: { reason: "mint_failed" }) do
      post game_win_code_path, params: win_claim, as: :json
    end

    assert_response :service_unavailable
  end

  test "a claim past the hourly per-IP limit is refused with a reason and reported" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    stub_mint("STACKMHR4T7")

    10.times { post game_win_code_path, params: win_claim, as: :json }

    assert_event_reported("game.win_claim_rejected", payload: { reason: "rate_limited" }) do
      post game_win_code_path, params: win_claim, as: :json
    end

    assert_response :too_many_requests
    assert_equal "rate_limited", response.parsed_body["error"]
  ensure
    Rails.cache = original_cache
  end
end
