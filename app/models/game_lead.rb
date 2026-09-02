# An email address The Afida Stack game captured — the bridge from plays to
# pipeline. One row per address: a later capture keeps the first source and
# can only ever upgrade marketing consent, never withdraw it silently. The
# row is also the win-claim record: one Stripe code per address per month.
class GameLead < ApplicationRecord
  SOURCES = %w[win board].freeze

  belongs_to :referrer, class_name: "LeaderboardEntry", optional: true

  normalizes :email, with: ->(e) { e.to_s.strip.downcase }

  validates :email, presence: true, uniqueness: { case_sensitive: false },
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :source, inclusion: { in: SOURCES }

  def self.capture(email:, source:, marketing_opt_in: false, referrer: nil)
    lead = find_or_initialize_by(email: normalize_value_for(:email, email))
    lead.source ||= source
    lead.referrer ||= referrer
    newly_opted_in = marketing_opt_in && !lead.marketing_opt_in
    lead.marketing_opt_in ||= marketing_opt_in
    transaction do
      lead.save!
      lead.sync_to_marketing_list if newly_opted_in
    end
    lead
  end

  # First claim this month mints; later claims return the stored code so
  # "Send again" resends rather than creating a second prize.
  def claim_win_code
    code = nil
    with_lock do
      month = Date.current.beginning_of_month
      if win_promo_code.present? && win_promo_month == month
        code = win_promo_code
      else
        code = Game::PromoCodes.mint_win_code
        update!(win_promo_code: code, win_promo_month: month)
      end
    end
    code
  end

  # One MATE code per referred address. Minting talks to Stripe, so it happens
  # outside the row lock; the lock only claims the payout.
  def claim_referral_code
    with_lock do
      reload
      return mate_promo_code if mate_promo_code.present?
    end

    code = Game::PromoCodes.mint_referral_code

    with_lock do
      reload
      return mate_promo_code if mate_promo_code.present?

      update!(mate_promo_code: code, referrer_rewarded_at: Time.current)
      code
    end
  end

  # Opted-in addresses join the canonical EmailSubscription list so Klaviyo
  # (which resolves signup events via subscription_id) actually sees them.
  def sync_to_marketing_list
    subscription = EmailSubscription.find_or_initialize_by(email: email)
    created = subscription.new_record?
    subscription.source = "game_#{source}" if created
    subscription.save!
    return unless created

    Rails.event.notify("email_signup.completed",
      subscription_id: subscription.id,
      source: subscription.source)
  end
end
