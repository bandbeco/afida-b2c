require "test_helper"

class Game::PromoCodesTest < ActiveSupport::TestCase
  MONTH = Date.current.strftime("%Y-%m")

  test "mints a single-use STACK code drawing on the month's win coupon, expiring with the month" do
    Stripe::Coupon.stubs(:retrieve).with("afida-stack-win-#{MONTH}").returns(stub(id: "afida-stack-win-#{MONTH}"))
    captured = nil
    Stripe::PromotionCode.stubs(:create).with { |p| captured = p; true }.returns(stub(code: "STACKMHR4T7"))

    assert_equal "STACKMHR4T7", Game::PromoCodes.mint_win_code

    assert_equal({ type: "coupon", coupon: "afida-stack-win-#{MONTH}" }, captured[:promotion])
    assert_match(/\ASTACK[#{Game::PromoCodes::CODE_ALPHABET.join}]{6}\z/, captured[:code])
    assert_equal 1, captured[:max_redemptions]
    assert_equal Time.current.end_of_month.to_i, captured[:expires_at]
    assert_equal({ minimum_amount: 10_000, minimum_amount_currency: "gbp" }, captured[:restrictions])
  end

  test "mints MATE codes against the month's referral coupon" do
    Stripe::Coupon.stubs(:retrieve).with("afida-stack-mate-#{MONTH}").returns(stub(id: "afida-stack-mate-#{MONTH}"))
    captured = nil
    Stripe::PromotionCode.stubs(:create).with { |p| captured = p; true }.returns(stub(code: "MATEC4NHW6"))

    assert_equal "MATEC4NHW6", Game::PromoCodes.mint_referral_code

    assert_equal({ type: "coupon", coupon: "afida-stack-mate-#{MONTH}" }, captured[:promotion])
    assert_match(/\AMATE[#{Game::PromoCodes::CODE_ALPHABET.join}]{6}\z/, captured[:code])
  end

  test "creates the coupon on first use, capped so a month's giveaway is bounded" do
    Stripe::Coupon.stubs(:retrieve).raises(Stripe::InvalidRequestError.new("No such coupon", "coupon"))
    captured = nil
    Stripe::Coupon.stubs(:create).with { |p| captured = p; true }.returns(stub(id: "afida-stack-win-#{MONTH}"))
    Stripe::PromotionCode.stubs(:create).returns(stub(code: "STACKJKX397"))

    assert_equal "STACKJKX397", Game::PromoCodes.mint_win_code

    assert_equal "afida-stack-win-#{MONTH}", captured[:id]
    assert_equal 5, captured[:percent_off]
    assert_equal "once", captured[:duration]
    assert_equal Game::PromoCodes::MONTHLY_REDEMPTION_CAP, captured[:max_redemptions]
    # Stripe rejects coupon names over 40 characters — a stub can't catch it
    assert_operator captured[:name].length, :<=, 40
  end
end
