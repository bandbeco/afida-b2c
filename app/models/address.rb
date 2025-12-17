class Address < ApplicationRecord
  # UK postcode format regex (case-insensitive)
  # Examples: SW1A 1AA, M1 1AA, B33 8TH, CR2 6XH, DN55 1PT
  UK_POSTCODE_REGEX = /\A
    ([A-Z]{1,2}[0-9][0-9A-Z]?)\s*  # Outward code: letters, digit, optional alphanumeric
    ([0-9][A-Z]{2})                 # Inward code: digit, two letters
  \z/ix

  MAX_ADDRESSES_PER_USER = 10

  belongs_to :user

  # Validations
  validates :nickname, presence: true, length: { maximum: 50 },
                      uniqueness: { scope: :user_id, message: "already used" }
  validate :address_limit_not_exceeded, on: :create
  validates :recipient_name, presence: true, length: { maximum: 100 }
  validates :company_name, length: { maximum: 100 }, allow_blank: true
  validates :line1, presence: true, length: { maximum: 200 }
  validates :line2, length: { maximum: 100 }, allow_blank: true
  validates :city, presence: true, length: { maximum: 100 }
  validates :postcode, presence: true, length: { maximum: 20 }
  validates :postcode, format: { with: UK_POSTCODE_REGEX, message: "is not a valid UK postcode" }, if: -> { country == "GB" }
  validates :phone, length: { maximum: 30 }, allow_blank: true
  validates :country, presence: true, format: { with: /\A[A-Z]{2}\z/, message: "must be a valid 2-letter country code" }

  # Scopes
  scope :default_first, -> { order(default: :desc, created_at: :asc) }

  # Callbacks
  before_save :ensure_single_default
  after_destroy :assign_new_default
  after_commit :sync_stripe_customer, on: [ :create, :update ], if: :should_sync_stripe?

  private

  # Only sync when address becomes the default (not when editing or creating non-default).
  # saved_change_to_default returns [old_value, new_value], so .last == true means
  # it changed TO true (either nil→true for new records, or false→true for existing).
  def should_sync_stripe?
    default? && saved_change_to_default? && saved_change_to_default.last == true
  end

  def address_limit_not_exceeded
    return unless user

    if user.addresses.count >= MAX_ADDRESSES_PER_USER
      errors.add(:base, "You can only save up to #{MAX_ADDRESSES_PER_USER} addresses")
    end
  end

  def ensure_single_default
    if default? && default_changed?
      user.addresses.where.not(id: id).update_all(default: false)
    end
  end

  def assign_new_default
    if default? && user.addresses.exists?
      user.addresses.order(:created_at).first.update!(default: true)
    end
  end

  # Sync default address to Stripe Customer for checkout prefill.
  # Uses async job to avoid blocking the request.
  def sync_stripe_customer
    StripeCustomerSyncJob.perform_later(user_id, id)
  end
end
