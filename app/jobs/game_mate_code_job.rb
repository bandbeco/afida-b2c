# Delivers a referrer's extra-5% code the moment a verified invite lands, so
# the reward reaches them without another visit. Emails at most once per
# entry: an already-minted code means they claimed it in-game (or a previous
# invite already delivered it), and re-sending would only confuse.
class GameMateCodeJob < ApplicationJob
  queue_as :default
  retry_on Stripe::StripeError, wait: :polynomially_longer, attempts: 5

  def perform(entry_id)
    entry = LeaderboardEntry.find_by(id: entry_id)
    return unless entry&.email&.present?
    return if entry.referral_promo_code.present?
    return if entry.verified_referrals.zero?

    entry.update!(referral_promo_code: Game::PromoCodes.mint_referral_code)
    GameMailer.mate_code(entry).deliver_later
  end
end
