# JSON API behind The Afida Stack game (a static page at /game/). The board is
# public; submissions carry a signed token issued with the board (proving when
# play could have started) and a drop log that Game::StackReplay re-runs
# server-side, so the recorded score is derived, never trusted.
class GameLeaderboardController < ApplicationController
  allow_unauthenticated_access

  # The game page is a static file with no CSRF token to embed; the signed
  # submission token, replay verification, and the per-IP ceiling stand in.
  skip_forgery_protection

  rate_limit to: 20, within: 1.hour, only: :create, store: LiveCacheStore,
    with: -> { render json: { error: "rate_limited" }, status: :too_many_requests }

  TOKEN_TTL = 6.hours
  # Real rounds spend well over a second per drop (fall time plus a swing);
  # 0.7s is lenient enough to never punish a fast human.
  MIN_SECONDS_PER_DROP = 0.7

  def self.token_verifier
    Rails.application.message_verifier(:game_leaderboard)
  end

  def index
    entries = LeaderboardEntry.current_top
    render json: {
      month: Date.current.strftime("%B %Y"),
      token: self.class.token_verifier.generate({ "issued_at" => Time.current.to_i }),
      entries: entries.map.with_index(1) do |entry, rank|
        { rank: rank, name: entry.name, score: entry.score, instagram_handle: entry.public_handle }
      end
    }
  end

  def create
    issued_at = verified_issued_at
    return render_rejection("invalid_token") unless issued_at

    replay = Game::StackReplay.new(canvas_width: params[:canvas_width], xs: params[:xs])
    return render_rejection("invalid_replay") unless replay.valid?
    return render_rejection("too_fast") if Time.current - issued_at < replay.score * MIN_SECONDS_PER_DROP

    screening = Game::EntryScreening.new(
      name: params[:name].to_s.strip,
      instagram_handle: params[:instagram_handle],
      score: replay.score,
      perfect_ratio: replay.perfect_ratio,
      current_best: LeaderboardEntry.for_month(Date.current).visible.maximum(:score),
      recent_from_ip: LeaderboardEntry.where(submitter_ip: request.remote_ip, created_at: 10.minutes.ago..).count
    )

    entry = LeaderboardEntry.new(
      name: params[:name].to_s.strip,
      instagram_handle: params[:instagram_handle],
      score: replay.score,
      status: screening.clean? && auto_approve? ? "approved" : "pending",
      flags: screening.flags,
      submitter_ip: request.remote_ip,
      replay: { canvas_width: params[:canvas_width], xs: params[:xs] }
    )
    if entry.save
      render json: { rank: entry.rank, score: entry.score }, status: :created
    else
      render_rejection("invalid_entry")
    end
  end

  private

  # Kill switch: set LEADERBOARD_AUTO_APPROVE=false to hold every entry for
  # review again (e.g. during a spam wave). Flagged entries always wait.
  def auto_approve?
    ENV.fetch("LEADERBOARD_AUTO_APPROVE", "true") != "false"
  end

  def verified_issued_at
    payload = self.class.token_verifier.verified(params[:token].to_s)
    return nil unless payload.is_a?(Hash) && payload["issued_at"].is_a?(Integer)

    issued_at = Time.zone.at(payload["issued_at"])
    issued_at if issued_at > TOKEN_TTL.ago
  end

  def render_rejection(reason)
    render json: { error: reason }, status: :unprocessable_entity
  end
end
