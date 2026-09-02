# The Afida Stack's prize claim (Game::PromoCodes). Codes travel by email
# only, never back to the browser — the address is where the prize goes and
# the lead the game exists to capture. A claim carries the same proof as a
# leaderboard submission (Game::VerifiedRun), so no code exists without a
# server-verified winning run behind it. CSRF comes from the Rails game
# page. The referral kickback has no claim UI: when a referred address
# places a first £100+ order, GameMateCodeJob emails the referrer £10 off.
class GamePromoCodesController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :set_current_cart, :set_nav_categories

  rate_limit to: 10, within: 1.hour, store: LiveCacheStore,
    with: -> { render json: { error: "rate_limited" }, status: :too_many_requests }

  BASE_WIN = 15
  INVITED_WIN = 12

  def win
    address = params[:email].to_s.strip.downcase
    return render_rejection("invalid_email") unless address.match?(URI::MailTo::EMAIL_REGEXP)

    run = Game::VerifiedRun.from(
      token: params[:token],
      canvas_width: params[:canvas_width],
      xs: params[:xs],
      ip: request.remote_ip,
      ref: params[:ref]
    )
    return render_rejection(run.error) unless run.ok?
    return render_rejection("below_target") if run.replay.score < win_target(run.referrer)

    lead = GameLead.capture(email: address, source: "win",
      marketing_opt_in: ActiveModel::Type::Boolean.new.cast(params[:marketing]) || false,
      referrer: run.referrer)
    code = lead.claim_win_code
    attach_own_email!(address)
    GameMailer.win_code(address, code).deliver_later
    head :ok
  rescue Stripe::StripeError => e
    Rails.logger.error("Stripe error minting a game code: #{e.message}")
    render json: { error: "mint_failed" }, status: :service_unavailable
  end

  private

  def win_target(referrer)
    referrer ? INVITED_WIN : BASE_WIN
  end

  # Codes travel by email, not on screen. The board form is not special: a
  # later win-claim address is enough to attach to the shareable ref entry
  # and to flush any referral payouts that were waiting on it.
  def attach_own_email!(address)
    entry = LeaderboardEntry.find_by(ref_code: params[:my_ref].to_s.downcase)
    return unless entry

    entry.update!(email: address) if entry.email.blank?
    entry.deliver_pending_referral_rewards
  end

  def render_rejection(reason)
    render json: { error: reason }, status: :unprocessable_entity
  end
end
