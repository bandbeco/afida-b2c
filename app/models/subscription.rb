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
    Stripe::Subscription.cancel(stripe_subscription_id)
    update!(status: :cancelled, cancelled_at: Time.current) unless cancelled?
  rescue Stripe::StripeError => e
    log_stripe_error("cancel", e)
    errors.add(:base, "Failed to cancel subscription: #{e.message}")
    raise ActiveRecord::RecordInvalid, self
  end

  def pause!
    Stripe::Subscription.update(stripe_subscription_id, pause_collection: { behavior: "void" })
    update!(status: :paused) unless paused?
  rescue Stripe::StripeError => e
    log_stripe_error("pause", e)
    errors.add(:base, "Failed to pause subscription: #{e.message}")
    raise ActiveRecord::RecordInvalid, self
  end

  def resume!
    Stripe::Subscription.update(stripe_subscription_id, pause_collection: "")
    update!(status: :active) unless active?
  rescue Stripe::StripeError => e
    log_stripe_error("resume", e)
    errors.add(:base, "Failed to resume subscription: #{e.message}")
    raise ActiveRecord::RecordInvalid, self
  end

  def items
    parsed_items_snapshot["items"] || []
  end

  def total_amount
    parsed_items_snapshot["total"]&.to_d || 0
  end

  def parsed_items_snapshot
    @parsed_items_snapshot ||= parse_json_field(items_snapshot)
  end

  def parsed_shipping_snapshot
    @parsed_shipping_snapshot ||= parse_json_field(shipping_snapshot)
  end

  def frequency_display
    frequency&.humanize
  end

  private

  def log_stripe_error(action, error)
    Rails.logger.error("Subscription##{id} #{action} failed: #{error.class} - #{error.message}")
  end

  def parse_json_field(value)
    return value if value.is_a?(Hash)
    return JSON.parse(value) if value.is_a?(String)
    {}
  rescue JSON::ParserError => e
    Rails.logger.error("Subscription##{id}: Failed to parse JSON - #{e.message}")
    {}
  end
end
