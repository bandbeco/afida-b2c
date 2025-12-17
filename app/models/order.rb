class Order < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :organization, optional: true
  belongs_to :placed_by_user, class_name: "User", optional: true
  belongs_to :reorder_schedule, optional: true
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :stripe_session_id, presence: true, uniqueness: true
  validates :order_number, presence: true, uniqueness: true
  validates :status, presence: true
  validates :subtotal_amount, :vat_amount, :shipping_amount, :total_amount,
            presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :shipping_name, :shipping_address_line1, :shipping_city,
            :shipping_postal_code, :shipping_country, presence: true

  enum :status, {
    pending: "pending",
    paid: "paid",
    processing: "processing",
    shipped: "shipped",
    delivered: "delivered",
    cancelled: "cancelled",
    refunded: "refunded"
  }

  enum :branded_order_status, {
    design_pending: "design_pending",
    design_approved: "design_approved",
    in_production: "in_production",
    production_complete: "production_complete",
    stock_received: "stock_received",
    instance_created: "instance_created"
  }, prefix: true, validate: { allow_nil: true }

  before_validation :generate_order_number, on: :create

  scope :recent, -> { order(created_at: :desc) }
  scope :for_organization, ->(org) { where(organization: org) }
  scope :branded_orders, -> {
    joins(:order_items)
      .where.not(order_items: { configuration: nil })
      .distinct
  }
  scope :with_samples, -> {
    joins(:order_items)
      .where(order_items: { is_sample: true })
      .distinct
  }

  def items_count
    order_items.sum(:quantity)
  end

  def full_shipping_address
    address_parts = [
      shipping_address_line1,
      shipping_address_line2,
      shipping_city,
      shipping_postal_code,
      shipping_country
    ].compact

    address_parts.join(", ")
  end

  def display_number
    "##{order_number}"
  end

  def b2b_order?
    organization_id.present?
  end

  def branded_order?
    order_items.any? { |item| item.configuration.present? }
  end

  # Returns true if any order items are samples (using is_sample flag)
  def contains_samples?
    order_items.samples.exists?
  end

  # Returns true if this is a samples-only order (no non-sample items)
  def sample_request?
    contains_samples? && order_items.non_samples.none?
  end

  # Generate a secure token for accessing this order without authentication
  # Used in email links for guest checkout orders
  def secure_access_token
    Digest::SHA256.hexdigest("#{id}-#{stripe_session_id}-#{Rails.application.secret_key_base}")
  end

  # Generate signed access token using Rails built-in signed global ID
  # More secure than custom token generation, with built-in expiration
  def signed_access_token
    to_sgid(expires_in: 30.days, for: "order_access").to_s
  end

  # Atomic GA4 tracking - returns true if THIS call set the timestamp
  # Uses update_all to prevent race condition when multiple requests hit simultaneously
  def mark_ga4_tracked!
    Order.where(id: id, ga4_purchase_tracked_at: nil)
         .update_all(ga4_purchase_tracked_at: Time.current) > 0
  end

  def ga4_tracked?
    ga4_purchase_tracked_at.present?
  end

  # Returns true if this order has an associated reorder schedule
  def has_reorder_schedule?
    reorder_schedule_id.present?
  end

  private

  def generate_order_number
    return if order_number.present?

    loop do
      # Generate order number like: 2025-A3X9K2 (11 chars total)
      # Full year (4 digits) + hyphen + 6 alphanumeric = 2.1B combinations/year
      year = Date.current.year
      random_part = SecureRandom.alphanumeric(6).upcase
      candidate = "#{year}-#{random_part}"

      unless Order.exists?(order_number: candidate)
        self.order_number = candidate
        break
      end
    end
  end
end
