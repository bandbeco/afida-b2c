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
  # Note: Newsletter-only subscribers (discount_claimed_at: nil) ARE eligible.
  #
  # @param email [String] the email address to check
  # @return [Boolean] true if eligible for discount
  def self.eligible_for_discount?(email)
    return false if email.blank?

    normalized_email = email.strip.downcase

    # Check if email has already claimed a discount (not just subscribed)
    return false if where(email: normalized_email).where.not(discount_claimed_at: nil).exists?

    # Check if email has previous orders
    return false if Order.exists?(email: normalized_email)

    true
  end

  # Check if an email has already claimed the discount.
  # Used for displaying "already claimed" vs allowing a new claim.
  def self.discount_already_claimed?(email)
    return false if email.blank?
    where(email: email.strip.downcase).where.not(discount_claimed_at: nil).exists?
  end
end
