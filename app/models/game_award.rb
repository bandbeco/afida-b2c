class GameAward < ApplicationRecord
  class SoldOut < StandardError; end
  belongs_to :game_participant, optional: true
  belongs_to :qualifying_order, class_name: "Order", optional: true
  belongs_to :redeemed_order, class_name: "Order", optional: true
  validates :kind, inclusion: { in: %w[win referral] }
  scope :usable, -> { where(redeemed_order_id: nil).where("expires_at > ?", Time.current) }

  def self.reserve!(email:, kind:, key:, game_participant: nil, qualifying_order: nil)
    existing = find_by(grant_key: key)
    return existing if existing

    month = Date.current.beginning_of_month
    budget = GamePrizeBudget.create_or_find_by!(kind: kind, month: month)
    budget.with_lock do
      existing = find_by(grant_key: key)
      return existing if existing
      raise SoldOut if budget.reserved >= GamePrizeBudget::CAP

      award = create!(email: email, kind: kind, grant_key: key, month: month,
        expires_at: 30.days.from_now, game_participant: game_participant, qualifying_order: qualifying_order)
      budget.increment!(:reserved)
      award
    end
  end

  def mint_code!
    with_lock do
      return code if code.present?
      update!(code: Game::PromoCodes.mint(kind == "win" ? Game::PromoCodes::WIN : Game::PromoCodes::REFERRAL, award: self))
      code
    end
  end
end
