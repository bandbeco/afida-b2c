class Subscription < ApplicationRecord
  belongs_to :user
  has_many :orders, dependent: :nullify

  validates :stripe_subscription_id, presence: true, uniqueness: true
  validates :stripe_customer_id, presence: true
  validates :stripe_price_id, presence: true
  validates :frequency, presence: true
  validates :status, presence: true
  validates :items_snapshot, presence: true
  validates :shipping_snapshot, presence: true

  enum :frequency, [ :every_week, :every_two_weeks, :every_month, :every_3_months ], validate: true
  enum :status, [ :active, :paused, :cancelled ], validate: true, default: :active

  scope :active_subscriptions, -> { where(status: :active) }

  def next_billing_date
    current_period_end
  end

  def cancel!
    update!(status: :cancelled, cancelled_at: Time.current)
  end

  def pause!
    update!(status: :paused)
  end

  def resume!
    update!(status: :active)
  end

  def items
    items_snapshot["items"] || []
  end

  def total_amount
    items_snapshot["total"]&.to_d || 0
  end

  def frequency_display
    frequency&.humanize
  end
end
