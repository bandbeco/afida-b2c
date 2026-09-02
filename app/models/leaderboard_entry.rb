# One player's run on The Afida Stack (/game), competing on the monthly board.
# The score is always derived server-side from the submitted drop replay
# (Game::StackReplay), never taken from the client. Moderation gates exposure,
# not existence: pending entries show name and score but hide the Instagram
# handle until approved; rejected entries vanish from the public board.
class LeaderboardEntry < ApplicationRecord
  TOP_SIZE = 10
  MAX_SCORE = 500

  enum :status, { pending: "pending", approved: "approved", rejected: "rejected" }, default: "pending"

  # The entry whose share link brought this player in.
  belongs_to :referrer, class_name: "LeaderboardEntry", optional: true

  before_create { self.ref_code ||= generate_ref_code }

  # Instagram allows letters, digits, dots and underscores; the game's name
  # input caps at 14 characters, mirrored here.
  normalizes :instagram_handle, with: ->(h) { h.to_s.strip.delete_prefix("@").downcase }
  # Email is never shown on the board — it's how prize codes and dethronement
  # news reach the player.
  normalizes :email, with: ->(e) { e.to_s.strip.downcase.presence }

  validates :name, presence: true, length: { maximum: 14 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
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

  # Referral £10s are emailed. If this entry had no address when a referred
  # lead ordered, the payout waits here until an email lands (win claim or
  # a later board join).
  def deliver_pending_referral_rewards
    return if email.blank?

    GameLead.where(referrer: self, referrer_rewarded_at: nil).find_each do |lead|
      order = Order.where(email: lead.email, status: Order::COMPLETED_STATUSES)
        .where(subtotal_amount: GameMateCodeJob::QUALIFYING_SUBTOTAL..)
        .order(:id)
        .first
      GameMateCodeJob.perform_later(order.id) if order
    end
  end

  def public_handle
    instagram_handle if approved? && instagram_handle.present?
  end

  # The referrer named by a share link, unless it points back at the player's
  # own address (self-invites earn nothing).
  def self.credited_referrer(ref_code, ip)
    return if ref_code.blank?

    referrer = find_by(ref_code: ref_code.to_s.downcase)
    referrer unless referrer&.submitter_ip == ip
  end

  private

  def generate_ref_code
    loop do
      code = SecureRandom.alphanumeric(6).downcase
      break code unless self.class.exists?(ref_code: code)
    end
  end
end
