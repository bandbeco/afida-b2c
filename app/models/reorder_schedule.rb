class ReorderSchedule < ApplicationRecord
  belongs_to :user
  has_many :reorder_schedule_items, dependent: :destroy
  has_many :product_variants, through: :reorder_schedule_items
  has_many :pending_orders, dependent: :destroy
  has_many :orders, dependent: :nullify

  accepts_nested_attributes_for :reorder_schedule_items, allow_destroy: true

  enum :frequency, {
    every_week: 0,
    every_two_weeks: 1,
    every_month: 2,
    every_3_months: 3
  }, validate: true

  enum :status, {
    active: 0,
    paused: 1,
    cancelled: 2
  }, validate: true, default: :active

  validates :next_scheduled_date, presence: true
  validates :stripe_payment_method_id, presence: true

  scope :active, -> { where(status: :active) }
  scope :due_in_days, ->(days) { where(next_scheduled_date: days.days.from_now.to_date) }

  def advance_schedule!
    self.next_scheduled_date = calculate_next_date
    save!
  end

  def pause!
    update!(status: :paused, paused_at: Time.current)
  end

  def resume!
    update!(status: :active, paused_at: nil, next_scheduled_date: calculate_next_date(from: Date.current))
  end

  def cancel!
    update!(status: :cancelled, cancelled_at: Time.current)
  end

  private

  def calculate_next_date(from: next_scheduled_date)
    case frequency
    when "every_week" then from + 1.week
    when "every_two_weeks" then from + 2.weeks
    when "every_month" then from + 1.month
    when "every_3_months" then from + 3.months
    end
  end
end
