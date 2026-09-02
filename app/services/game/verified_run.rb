module Game
  # The proof both game endpoints share: a signed board token, a drop log that
  # StackReplay can re-run, and enough elapsed time that a human could have
  # played it. Callers branch on #ok? / #error; a verified run also carries the
  # credited referrer (or nil) so win-threshold and board-credit stay in one place.
  class VerifiedRun
    TOKEN_TTL = 6.hours
    # Real rounds spend well over a second per drop (fall time plus a swing);
    # 0.7s is lenient enough to never punish a fast human.
    MIN_SECONDS_PER_DROP = 0.7

    attr_reader :error, :replay, :referrer

    def self.token_verifier
      Rails.application.message_verifier(:game_leaderboard)
    end

    def self.issue_token
      token_verifier.generate({ "issued_at" => Time.current.to_i })
    end

    def self.from(token:, canvas_width:, xs:, ip:, ref: nil)
      new(token: token, canvas_width: canvas_width, xs: xs, ip: ip, ref: ref)
    end

    def initialize(token:, canvas_width:, xs:, ip:, ref: nil)
      @token = token
      @canvas_width = canvas_width
      @xs = xs
      @ip = ip
      @ref = ref
      verify
    end

    def ok?
      error.nil?
    end

    private

    def verify
      issued_at = verified_issued_at
      unless issued_at
        @error = "invalid_token"
        return
      end

      replay = StackReplay.new(canvas_width: @canvas_width, xs: @xs)
      unless replay.valid?
        @error = "invalid_replay"
        return
      end

      if Time.current - issued_at < replay.score * MIN_SECONDS_PER_DROP
        @error = "too_fast"
        return
      end

      @replay = replay
      @referrer = LeaderboardEntry.credited_referrer(@ref, @ip)
    end

    def verified_issued_at
      payload = self.class.token_verifier.verified(@token.to_s)
      return unless payload.is_a?(Hash) && payload["issued_at"].is_a?(Integer)

      issued_at = Time.zone.at(payload["issued_at"])
      issued_at if issued_at > TOKEN_TTL.ago
    end
  end
end
