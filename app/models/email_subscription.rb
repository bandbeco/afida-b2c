class EmailSubscription < ApplicationRecord
  # Normalize email: strip whitespace and convert to lowercase
  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :source, presence: true

  # Check if an email is eligible for the first-order discount.
  #
  # Returns false if:
  # - Email is blank
  # - Email has already claimed a discount (discount_claimed_at is set)
  # - Email has previous orders (exists in orders table)
  #
  # IMPORTANT: Newsletter-only subscribers (discount_claimed_at: nil) ARE eligible.
  # This allows the "upgrade" flow where someone signs up for the newsletter first,
  # then later claims the discount when they're ready to purchase. The controller
  # uses find_or_initialize_by to update the existing record rather than creating
  # a duplicate (which the unique index on email would reject anyway).
  #
  # @param email [String] the email address to check
  # @return [Boolean] true if eligible for discount
  def self.eligible_for_discount?(email)
    discount_ineligibility_reason(email).nil?
  end

  # Why this email cannot claim the welcome discount, or nil if it can. This is the
  # single definition of CLAIM-time eligibility: eligible_for_discount? is the boolean
  # view of it, and the signup controller branches on the reason to explain the refusal.
  #
  # Checkout::SessionBuilder deliberately does NOT reuse this when the coupon is spent:
  # claiming stamps discount_claimed_at, so this rule would refuse the very order the
  # coupon was claimed for. See welcome_discount_allowed? there.
  #
  # An already-claimed discount is reported ahead of order history so someone who
  # claimed and then ordered is told they already used it, rather than being told they
  # are a returning customer who never had one.
  #
  # @param email [String] the email address to check
  # @return [Symbol, nil] :blank_email, :already_claimed, :has_previous_orders, or nil
  def self.discount_ineligibility_reason(email)
    return :blank_email if email.blank?

    normalized_email = email.strip.downcase

    return :already_claimed if where(email: normalized_email).where.not(discount_claimed_at: nil).exists?
    return :has_previous_orders if Order.exists?(email: normalized_email)

    nil
  end

  # Check if an email has already claimed the discount.
  # Used for displaying "already claimed" vs allowing a new claim.
  def self.discount_already_claimed?(email)
    return false if email.blank?
    where(email: email.strip.downcase).where.not(discount_claimed_at: nil).exists?
  end
end
