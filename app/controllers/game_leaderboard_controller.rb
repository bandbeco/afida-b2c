# JSON API behind The Afida Stack game at /game. The board is public;
# submissions carry a signed token issued with the board (proving when play
# could have started) and a drop log that Game::VerifiedRun re-runs
# server-side, so the recorded score is derived, never trusted.
class GameLeaderboardController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :set_current_cart, :set_nav_categories

  rate_limit to: 20, within: 1.hour, only: :create, store: LiveCacheStore,
    with: -> { render json: { error: "rate_limited" }, status: :too_many_requests }

  def index
    render json: Game.board
  end

  def create
    run = verified_run
    return render_rejection(run.error) unless run.ok?

    screening = Game::EntryScreening.new(
      name: params[:name].to_s.strip,
      instagram_handle: params[:instagram_handle],
      score: run.replay.score,
      perfect_ratio: run.replay.perfect_ratio,
      current_best: LeaderboardEntry.for_month(Date.current).visible.maximum(:score),
      recent_from_ip: LeaderboardEntry.where(submitter_ip: request.remote_ip, created_at: 10.minutes.ago..).count
    )

    previous_leader = LeaderboardEntry.current_top.first

    entry = LeaderboardEntry.new(
      name: params[:name].to_s.strip,
      instagram_handle: params[:instagram_handle],
      email: params[:email],
      marketing_opt_in: marketing_opt_in?,
      score: run.replay.score,
      status: screening.clean? && auto_approve? ? "approved" : "pending",
      flags: screening.flags,
      submitter_ip: request.remote_ip,
      referrer: run.referrer,
      replay: { canvas_width: params[:canvas_width], xs: params[:xs] }
    )
    if entry.save
      if entry.email.present?
        GameLead.capture(email: entry.email, source: "board",
          marketing_opt_in: entry.marketing_opt_in, referrer: entry.referrer)
        entry.deliver_pending_referral_rewards
      end
      notify_dethroned(previous_leader, entry)
      render json: { rank: entry.rank, score: entry.score, ref_code: entry.ref_code }, status: :created
    else
      render_rejection("invalid_entry")
    end
  end

  private

  def verified_run
    Game::VerifiedRun.from(
      token: params[:token],
      canvas_width: params[:canvas_width],
      xs: params[:xs],
      ip: request.remote_ip,
      ref: params[:ref]
    )
  end

  # Kill switch: set LEADERBOARD_AUTO_APPROVE=false to hold every entry for
  # review again (e.g. during a spam wave). Flagged entries always wait.
  def auto_approve?
    ENV.fetch("LEADERBOARD_AUTO_APPROVE", "true") != "false"
  end

  # Losing the top spot is the one board change worth an email — it's the
  # nudge that brings last month's winner back to defend the crown.
  def notify_dethroned(previous_leader, entry)
    return unless previous_leader&.email&.present?
    return unless entry.score > previous_leader.score

    GameMailer.dethroned(previous_leader, by: entry).deliver_later
  end

  def marketing_opt_in?
    ActiveModel::Type::Boolean.new.cast(params[:marketing]) || false
  end

  def render_rejection(reason)
    render json: { error: reason }, status: :unprocessable_entity
  end
end
