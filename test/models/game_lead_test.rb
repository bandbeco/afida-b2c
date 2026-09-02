require "test_helper"

class GameLeadTest < ActiveSupport::TestCase
  test "requires a plausible email and a known source" do
    assert_not GameLead.new(email: "not-an-email", source: "win").valid?
    assert_not GameLead.new(email: "cafe@example.com", source: "mystery").valid?
    assert GameLead.new(email: "cafe@example.com", source: "win").valid?
  end

  test "capture stores one row per address, case-insensitively" do
    GameLead.capture(email: "Cafe@Example.com", source: "win")
    GameLead.capture(email: "cafe@example.com", source: "board")

    assert_equal 1, GameLead.count
    assert_equal "cafe@example.com", GameLead.first.email
  end

  test "capture keeps the first source and never downgrades marketing consent" do
    GameLead.capture(email: "cafe@example.com", source: "win", marketing_opt_in: true)
    lead = GameLead.capture(email: "cafe@example.com", source: "board", marketing_opt_in: false)

    assert_equal "win", lead.source
    assert lead.marketing_opt_in
  end

  test "capture upgrades consent when a later opt-in arrives" do
    GameLead.capture(email: "cafe@example.com", source: "win")
    lead = GameLead.capture(email: "cafe@example.com", source: "win", marketing_opt_in: true)

    assert lead.marketing_opt_in
  end

  test "capture raises when the address is implausible" do
    assert_raises(ActiveRecord::RecordInvalid) do
      GameLead.capture(email: "not-an-email", source: "win")
    end
  end

  test "opting in to marketing signs the address up and emits the canonical signup event" do
    assert_event_reported("email_signup.completed") do
      GameLead.capture(email: "cafe@example.com", source: "win", marketing_opt_in: true)
    end

    subscription = EmailSubscription.find_by(email: "cafe@example.com")
    assert_equal "game_win", subscription.source
  end

  test "a later capture without consent does not emit again" do
    GameLead.capture(email: "cafe@example.com", source: "win", marketing_opt_in: true)

    assert_no_event_reported("email_signup.completed") do
      GameLead.capture(email: "cafe@example.com", source: "board", marketing_opt_in: false)
    end
  end

  test "an address already on the marketing list is not signed up twice" do
    EmailSubscription.create!(email: "cafe@example.com", source: "cart_discount")

    assert_no_event_reported("email_signup.completed") do
      GameLead.capture(email: "cafe@example.com", source: "win", marketing_opt_in: true)
    end
  end

  test "claim_win_code mints once per address per month and resends that code after" do
    Stripe::Coupon.stubs(:retrieve).returns(stub(id: "afida-stack-win"))
    Stripe::PromotionCode.stubs(:create).returns(stub(code: "STACKMHR4T7"))

    lead = GameLead.capture(email: "cafe@example.com", source: "win")
    first = lead.claim_win_code

    Stripe::PromotionCode.stubs(:create).returns(stub(code: "STACKXXXXXX"))
    second = lead.claim_win_code

    assert_equal "STACKMHR4T7", first
    assert_equal "STACKMHR4T7", second
    assert_equal "STACKMHR4T7", lead.reload.win_promo_code
    assert_equal Date.current.beginning_of_month, lead.win_promo_month
  end

  test "a new month mints a fresh win code" do
    Stripe::Coupon.stubs(:retrieve).returns(stub(id: "afida-stack-win"))
    Stripe::PromotionCode.stubs(:create).returns(stub(code: "STACKMHR4T7"))

    lead = GameLead.capture(email: "cafe@example.com", source: "win")
    lead.claim_win_code

    travel_to Date.current.next_month.beginning_of_month + 1.day do
      Stripe::PromotionCode.stubs(:create).returns(stub(code: "STACKNEWMON"))

      assert_equal "STACKNEWMON", lead.claim_win_code
      assert_equal "STACKNEWMON", lead.reload.win_promo_code
    end
  end
end
