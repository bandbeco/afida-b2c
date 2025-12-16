class User < ApplicationRecord
  include EmailAddressVerification
  has_email_address_verification

  has_secure_password
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  belongs_to :organization, optional: true
  has_many :sessions, dependent: :destroy
  has_many :carts, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :addresses, dependent: :destroy
  has_many :reorder_schedules, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true

  enum :role, { owner: "owner", admin: "admin", member: "member" }, validate: { allow_nil: true }

  validates :role, presence: true, if: :organization_id?
  validate :organization_has_one_owner, if: -> { organization_id? && role == "owner" }

  def admin?
    role == "admin"
  end

  def initials
    if [ first_name, last_name ].all?(&:present?)
      first_name.first.upcase + last_name.first.upcase
    else
      email_address.split("@").first.split(".").map(&:first).join.upcase
    end
  end

  def verify_email_address!
    update!(email_address_verified: true)
  end

  # Get or create a Stripe Customer for this user
  # Used for saving payment methods for reorder schedules
  def stripe_customer
    return Stripe::Customer.retrieve(stripe_customer_id) if stripe_customer_id.present?

    customer = Stripe::Customer.create(
      email: email_address,
      name: [ first_name, last_name ].compact.join(" ").presence,
      metadata: { user_id: id }
    )
    update!(stripe_customer_id: customer.id)
    customer
  end

  def email_address_verification_token_expired?
    email_address_verification_token_expires_at < Time.current
  end

  # Returns the user's default address, or the oldest address if no default is set
  def default_address
    addresses.find_by(default: true) || addresses.order(:created_at).first
  end

  # Returns true if user has any saved addresses
  def has_saved_addresses?
    addresses.exists?
  end

  # Returns true if the given address (line1 + postcode) matches any saved address
  def has_matching_address?(line1:, postcode:)
    addresses.exists?(line1: line1, postcode: postcode)
  end

  # Returns true if this user has a Stripe Customer ID
  def has_stripe_customer?
    stripe_customer_id.present?
  end

  # Syncs user with Stripe Customer, creating if necessary.
  # Optionally syncs a specific address (defaults to default_address).
  def sync_stripe_customer!(address: nil)
    StripeCustomerSyncService.sync(self, address: address)
  end

  private

  def organization_has_one_owner
    return unless organization

    existing_owner = organization.users.where(role: "owner").where.not(id: id).exists?
    if existing_owner
      errors.add(:role, "organization already has an owner")
    end
  end
end
