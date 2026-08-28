module Game
  # Decides whether a leaderboard submission can go live unmoderated or should
  # wait for a human. Returns flags naming what looked off; an empty list means
  # clean. Flags route an entry to review, never reject it outright — false
  # positives (the Scunthorpe problem is real) cost a short wait, not a refusal.
  class EntryScreening
    # Deliberately blunt substring matching after normalization. Kept short:
    # this only has to catch drive-by abuse, the admin queue catches the rest.
    BLOCKLIST = %w[
      fuck shit cunt bitch bastard wanker twat prick cock bollocks arsehole
      asshole nigger nigga faggot retard whore slut porn nazi hitler
    ].freeze
    IMPERSONATION = %w[afida admin official support staff].freeze
    LEET = { "0" => "o", "1" => "i", "3" => "e", "4" => "a", "5" => "s", "7" => "t", "@" => "a", "$" => "s" }.freeze

    SCORE_CEILING = 40
    OUTLIER_MIN_BEST = 10
    PERFECT_RUN_MIN_SCORE = 20
    PERFECT_RUN_RATIO = 0.9
    BURST_LIMIT = 5

    def initialize(name:, instagram_handle:, score:, perfect_ratio:, current_best:, recent_from_ip:)
      @name = name.to_s
      @instagram_handle = instagram_handle.to_s
      @score = score.to_i
      @perfect_ratio = perfect_ratio.to_f
      @current_best = current_best
      @recent_from_ip = recent_from_ip.to_i
    end

    def flags
      @flags ||= [
        ("profanity" if matches?(BLOCKLIST)),
        ("impersonation" if matches?(IMPERSONATION)),
        ("high_score" if @score >= SCORE_CEILING),
        ("outlier_score" if outlier_score?),
        ("perfect_run" if perfect_run?),
        ("burst" if @recent_from_ip >= BURST_LIMIT)
      ].compact
    end

    def clean?
      flags.empty?
    end

    private

    def matches?(words)
      text = normalized_text
      words.any? { |word| text.include?(word) }
    end

    def normalized_text
      @normalized_text ||= "#{@name} #{@instagram_handle}"
        .downcase
        .gsub(/[013457@$]/, LEET)
        .gsub(/[^a-z]/, "")
    end

    def outlier_score?
      @current_best.present? && @current_best >= OUTLIER_MIN_BEST && @score >= @current_best * 2
    end

    def perfect_run?
      @score >= PERFECT_RUN_MIN_SCORE && @perfect_ratio > PERFECT_RUN_RATIO
    end
  end
end
