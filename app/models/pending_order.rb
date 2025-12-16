class PendingOrder < ApplicationRecord
  belongs_to :reorder_schedule
  belongs_to :order, optional: true

  enum :status, {
    pending: 0,
    confirmed: 1,
    expired: 2
  }, validate: true, default: :pending

  validates :items_snapshot, presence: true
  validates :scheduled_for, presence: true

  scope :pending, -> { where(status: :pending) }
  scope :expired_unprocessed, -> { pending.where("scheduled_for < ?", Date.current) }

  def confirm!(order)
    update!(
      status: :confirmed,
      order: order,
      confirmed_at: Time.current
    )
  end

  def expire!
    update!(status: :expired, expired_at: Time.current)
  end

  def items
    (items_snapshot["items"] || []).map(&:with_indifferent_access)
  end

  def total_amount
    items_snapshot["total"]&.to_d || 0
  end

  def subtotal_amount
    items_snapshot["subtotal"]&.to_d || 0
  end

  def vat_amount
    items_snapshot["vat"]&.to_d || 0
  end

  def unavailable_items
    (items_snapshot["unavailable_items"] || []).map(&:with_indifferent_access)
  end

  # Generate signed token for email links
  def confirmation_token
    to_sgid(expires_in: 7.days, for: "pending_order_confirm").to_s
  end

  def edit_token
    to_sgid(expires_in: 7.days, for: "pending_order_edit").to_s
  end
end
