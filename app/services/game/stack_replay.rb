module Game
  # Re-runs a submitted Afida Stack game from its drop log and decides whether
  # the run was geometrically possible. The client sends only the left edge of
  # each dropped block (xs) plus its canvas width; block widths are derived
  # here with the same slice rules the game applies client-side, so a forged
  # score has to be accompanied by a sequence of drops that could actually
  # produce it. This proves the run was *playable*, not that it was played —
  # the submission token's minimum-elapsed check and rate limiting carry the
  # rest of the burden.
  class StackReplay
    # Mirrors the constants in public/game/index.html — change them together.
    MIN_OVERLAP = 10
    PERFECT_TOL = 7
    PERFECT_GROWTH = 4
    BASE_MIN_W = 120
    BASE_MAX_W = 230
    BASE_RATIO = 0.46
    CANVAS_RANGE = (200..4000)
    MAX_DROPS = LeaderboardEntry::MAX_SCORE

    def initialize(canvas_width:, xs:)
      @canvas_width = canvas_width
      @xs = xs
    end

    def valid?
      return @valid if defined?(@valid)
      @valid = replay
    end

    # The verified score: one point per legal drop. Nil when the run is invalid.
    def score
      valid? ? @xs.size : nil
    end

    # Share of drops inside the perfect tolerance — the suspicion screening
    # uses this to spot bot-grade consistency. Nil when the run is invalid.
    def perfect_ratio
      valid? ? @perfect_count.to_f / @xs.size : nil
    end

    private

    def replay
      return false unless @canvas_width.is_a?(Numeric) && CANVAS_RANGE.cover?(@canvas_width)
      return false unless @xs.is_a?(Array) && @xs.size.between?(1, MAX_DROPS)
      return false unless @xs.all? { |x| x.is_a?(Numeric) }

      base_w = (@canvas_width * BASE_RATIO).clamp(BASE_MIN_W, BASE_MAX_W)
      prev_x = (@canvas_width - base_w) / 2.0
      prev_w = base_w
      @perfect_count = 0

      @xs.each do |x|
        return false unless x > -prev_w && x < @canvas_width

        dx = x - prev_x
        if dx.abs <= PERFECT_TOL
          @perfect_count += 1
          w = [ prev_w + PERFECT_GROWTH, base_w ].min
          prev_x -= (w - prev_w) / 2.0
          prev_w = w
        else
          left = [ x, prev_x ].max
          right = [ x + prev_w, prev_x + prev_w ].min
          overlap = right - left
          return false if overlap < MIN_OVERLAP

          prev_x = left
          prev_w = overlap
        end
      end

      true
    end
  end
end
