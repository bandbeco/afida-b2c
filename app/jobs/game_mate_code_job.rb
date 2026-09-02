# Pays a referrer £10 when someone they sent places a first order of £100+
# excl. VAT. One payout per referred address. The code is emailed, so we need
# some address on the referrer (board join or a later win claim) — if none is
# on file yet, this no-ops and retries once an email is attached.
class GameMateCodeJob < ApplicationJob
  queue_as :default
  retry_on Stripe::StripeError, wait: :polynomially_longer, attempts: 5

  QUALIFYING_SUBTOTAL = 100

  def perform(order_id)
    order = Order.find_by(id: order_id)
    return unless order
    return unless Order::COMPLETED_STATUSES.include?(order.status)
    return if order.sample_request?
    return if order.subtotal_amount < QUALIFYING_SUBTOTAL

    lead = GameLead.find_by(email: order.email)
    referrer = lead&.referrer
    return unless referrer&.email.present?
    return if lead.referrer_rewarded_at.present?
    return if prior_qualifying_order?(order)

    code = nil
    lead.with_lock do
      lead.reload
      next if lead.referrer_rewarded_at.present?

      code = Game::PromoCodes.mint_referral_code
      lead.update!(referrer_rewarded_at: Time.current)
    end
    GameMailer.mate_code(referrer.email, code).deliver_later if code
  end

  private

  def prior_qualifying_order?(order)
    Order.where(email: order.email, status: Order::COMPLETED_STATUSES)
      .where(subtotal_amount: QUALIFYING_SUBTOTAL..)
      .where.not(id: order.id)
      .exists?
  end
end
