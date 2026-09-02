# The Afida Stack's prize claim (Game::PromoCodes). Codes travel by email
# only, never back to the browser — the address is where the prize goes and
# the lead the game exists to capture. A claim carries the same proof as a
# leaderboard submission (Game::VerifiedRun), so no code exists without a
# server-verified winning run behind it. CSRF comes from the Rails game
# page. The referral kickback has no endpoint at all: a verified invite
# triggers GameMateCodeJob, which emails the referrer.
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
      marketing_opt_in: ActiveModel::Type::Boolean.new.cast(params[:marketing]) || false)
    code = lead.claim_win_code
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

  def render_rejection(reason)
    render json: { error: reason }, status: :unprocessable_entity
  end
end
