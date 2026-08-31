# Mints The Afida Stack's prize codes (Game::PromoCodes). A win claim carries
# the same proof as a leaderboard submission — the signed board token plus the
# drop log, re-run through Game::StackReplay — so no code exists without a
# server-verified winning run behind it.
class GamePromoCodesController < ApplicationController
  allow_unauthenticated_access

  # Same trade as the leaderboard: the game page is static with no CSRF token,
  # so verification and the per-IP ceiling stand in.
  skip_forgery_protection

  rate_limit to: 10, within: 1.hour, store: LiveCacheStore,
    with: -> { render json: { error: "rate_limited" }, status: :too_many_requests }

  BASE_WIN = 15
  INVITED_WIN = 12
  CODE_SHAPE = /\A(STACK|MATE)[#{Game::PromoCodes::CODE_ALPHABET.join}]{6}\z/

  def win
    issued_at = verified_issued_at
    return render_rejection("invalid_token") unless issued_at

    replay = Game::StackReplay.new(canvas_width: params[:canvas_width], xs: params[:xs])
    return render_rejection("invalid_replay") unless replay.valid?
    return render_rejection("too_fast") if Time.current - issued_at < replay.score * GameLeaderboardController::MIN_SECONDS_PER_DROP
    return render_rejection("below_target") if replay.score < win_target

    render json: { code: Game::PromoCodes.mint_win_code }
  rescue Stripe::StripeError => e
    Rails.logger.error("Stripe error minting a game code: #{e.message}")
    render json: { error: "mint_failed" }, status: :service_unavailable
  end

  # One referral code per board entry (entries are monthly): minted on the
  # first claim, re-shown on every claim after.
  def referral
    entry = LeaderboardEntry.find_by(ref_code: params[:me].to_s.downcase)
    return render_rejection("unknown_code") unless entry
    return render_rejection("no_verified_invites") if entry.verified_referrals.zero?

    entry.update!(referral_promo_code: Game::PromoCodes.mint_referral_code) if entry.referral_promo_code.blank?
    render json: { code: entry.referral_promo_code }
  rescue Stripe::StripeError => e
    Rails.logger.error("Stripe error minting a game code: #{e.message}")
    render json: { error: "mint_failed" }, status: :service_unavailable
  end

  # Emails a code the player already holds. Possession of a code Stripe knows
  # as active is the proof here — no replay needed — and the address becomes a
  # lead. The shape check keeps arbitrary strings out of outgoing mail.
  def email
    address = params[:email].to_s.strip.downcase
    return render_rejection("invalid_email") unless address.match?(URI::MailTo::EMAIL_REGEXP)

    code = params[:code].to_s.strip.upcase
    return render_rejection("invalid_code") unless code.match?(CODE_SHAPE)
    return render_rejection("unknown_promo") unless Game::PromoCodes.active?(code)

    GameLead.capture(email: address, source: "win",
      marketing_opt_in: ActiveModel::Type::Boolean.new.cast(params[:marketing]) || false)
    GameMailer.win_code(address, code).deliver_later
    head :ok
  rescue Stripe::StripeError => e
    Rails.logger.error("Stripe error minting a game code: #{e.message}")
    render json: { error: "mint_failed" }, status: :service_unavailable
  end

  private

  # Mirrors the leaderboard's credited_referrer: an invite lowers the target
  # only when it names a real entry that isn't the claimant's own address.
  def win_target
    return BASE_WIN if params[:ref].blank?

    referrer = LeaderboardEntry.find_by(ref_code: params[:ref].to_s.downcase)
    referrer && referrer.submitter_ip != request.remote_ip ? INVITED_WIN : BASE_WIN
  end

  def verified_issued_at
    payload = GameLeaderboardController.token_verifier.verified(params[:token].to_s)
    return nil unless payload.is_a?(Hash) && payload["issued_at"].is_a?(Integer)

    issued_at = Time.zone.at(payload["issued_at"])
    issued_at if issued_at > GameLeaderboardController::TOKEN_TTL.ago
  end

  def render_rejection(reason)
    render json: { error: reason }, status: :unprocessable_entity
  end
end
