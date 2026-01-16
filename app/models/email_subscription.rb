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
  # - Email has already claimed a discount (exists in email_subscriptions)
  # - Email has previous orders (exists in orders table)
  #
  # @param email [String] the email address to check
  # @return [Boolean] true if eligible for discount
  def self.eligible_for_discount?(email)
    return false if email.blank?

    normalized_email = email.strip.downcase

    # Check if email already exists in subscriptions
    return false if exists?(email: normalized_email)

    # Check if email has previous orders
    return false if Order.exists?(email: normalized_email)

    true
  end
end
