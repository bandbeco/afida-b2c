# One player's run on The Afida Stack (/game), competing on the monthly board.
# The score is always derived server-side from the submitted drop replay
# (Game::StackReplay), never taken from the client. Moderation gates exposure,
# not existence: pending entries show name and score but hide the Instagram
# handle until approved; rejected entries vanish from the public board.
class LeaderboardEntry < ApplicationRecord
  TOP_SIZE = 10
  MAX_SCORE = 500

  enum :status, { pending: "pending", approved: "approved", rejected: "rejected" }, default: "pending"

  # Instagram allows letters, digits, dots and underscores; the game's name
  # input caps at 14 characters, mirrored here.
  normalizes :instagram_handle, with: ->(h) { h.to_s.strip.delete_prefix("@").downcase }

  validates :name, presence: true, length: { maximum: 14 }
  validates :score, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_SCORE }
  validates :instagram_handle, format: { with: /\A[a-z0-9._]{1,30}\z/ }, allow_blank: true

  before_validation { self.month ||= Date.current.beginning_of_month }

  scope :for_month, ->(date) { where(month: date.to_date.beginning_of_month) }
  scope :visible, -> { where.not(status: "rejected") }
  scope :best_first, -> { order(score: :desc, created_at: :asc) }

  def self.current_top
    for_month(Date.current).visible.best_first.limit(TOP_SIZE)
  end

  # 1-based position among this month's visible entries.
  def rank
    self.class.for_month(month).visible.where("score > ?", score).count + 1
  end

  def public_handle
    instagram_handle if approved? && instagram_handle.present?
  end
end
