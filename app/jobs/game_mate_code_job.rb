# Delivers a referrer's extra-5% code the moment a verified invite lands, so
# the reward reaches them without another visit. Emails at most once per
# entry: an already-minted code means they claimed it in-game (or a previous
# invite already delivered it), and re-sending would only confuse.
class GameMateCodeJob < ApplicationJob
  queue_as :default
  retry_on Stripe::StripeError, wait: :polynomially_longer, attempts: 5

  def perform(entry_id)
    entry = LeaderboardEntry.find_by(id: entry_id)
    return unless entry

    minted = false
    entry.with_lock do
      if entry.email.present? && entry.referral_promo_code.blank? && entry.verified_referrals.positive?
        entry.update!(referral_promo_code: Game::PromoCodes.mint_referral_code)
        minted = true
      end
    end
    GameMailer.mate_code(entry.reload).deliver_later if minted
  end
end
