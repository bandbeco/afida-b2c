require "test_helper"

class GameAwardTest < ActiveSupport::TestCase
  test "a reserved prize survives the calendar boundary and cannot be displaced by later winners" do
    travel_to Time.zone.local(2026, 9, 30, 23, 50) do
      award = GameAward.reserve!(email: "winner@example.com", kind: "win", key: "test-win")
      assert_in_delta 30.days, award.expires_at - Time.current, 1
      assert_equal award, GameAward.reserve!(email: "winner@example.com", kind: "win", key: "test-win")
      budget = GamePrizeBudget.find_by!(kind: "win", month: Date.current.beginning_of_month)
      budget.update!(reserved: 200)
      assert_raises(GameAward::SoldOut) do
        GameAward.reserve!(email: "another@example.com", kind: "win", key: "another-win")
      end
      Game::PromoCodes.stubs(:mint).returns("STACKRESERVED")
      assert_equal "STACKRESERVED", award.mint_code!
    end
  end

  test "Stripe retries retain the same award and idempotency identity" do
    award = GameAward.reserve!(email: "winner@example.com", kind: "win", key: "retry")
    Game::PromoCodes.expects(:mint).with(Game::PromoCodes::WIN, award: award).raises(Stripe::APIConnectionError.new("offline"))
    assert_raises(Stripe::APIConnectionError) { award.mint_code! }
    assert_equal 1, GameAward.where(grant_key: "retry").count
    Game::PromoCodes.expects(:mint).with(Game::PromoCodes::WIN, award: award).returns("STACKRETRY")
    assert_equal "STACKRETRY", award.mint_code!
    assert_equal "STACKRETRY", award.reload.mint_code!
  end
end
