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
  validate :must_have_at_least_one_item, on: :update, if: -> { active? && items_being_modified? }

  scope :active, -> { where(status: :active) }
  scope :due_in_days, ->(days) { where(next_scheduled_date: days.days.from_now.to_date) }

  def advance_schedule!
    self.next_scheduled_date = calculate_next_date
    save!
  end

  def pause!
    update!(status: :paused, paused_at: Time.current)
  end

  # Resume a paused schedule with choice of when to send next delivery
  # @param resume_type [Symbol] :asap (default) or :original_schedule
  #   - :asap - Next delivery based on frequency from today
  #   - :original_schedule - Keep original schedule, advancing if date has passed
  def resume!(resume_type: :asap)
    next_date = case resume_type
    when :original_schedule
      # Advance original schedule until it's in the future
      date = next_scheduled_date
      date = calculate_next_date(from: date) while date <= Date.current
      date
    else # :asap
      calculate_next_date(from: Date.current)
    end

    update!(status: :active, paused_at: nil, next_scheduled_date: next_date)
  end

  def cancel!
    update!(status: :cancelled, cancelled_at: Time.current)
  end

  private

  def items_being_modified?
    # Only validate items when they're being changed via nested attributes
    reorder_schedule_items.any?(&:marked_for_destruction?) ||
      reorder_schedule_items.any? { |item| item.new_record? || item.changed? }
  end

  def must_have_at_least_one_item
    # Count items that aren't marked for destruction (nested attributes)
    remaining_items = reorder_schedule_items.reject(&:marked_for_destruction?)
    if remaining_items.empty?
      errors.add(:base, "Schedule must have at least one item. Pause or cancel instead.")
    end
  end

  def calculate_next_date(from: next_scheduled_date)
    case frequency
    when "every_week" then from + 1.week
    when "every_two_weeks" then from + 2.weeks
    when "every_month" then from + 1.month
    when "every_3_months" then from + 3.months
    end
  end
end
