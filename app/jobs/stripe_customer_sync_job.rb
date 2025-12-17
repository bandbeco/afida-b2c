# Background job to sync user address with Stripe Customer.
# Runs asynchronously to avoid blocking address save requests.
class StripeCustomerSyncJob < ApplicationJob
  queue_as :default

  # Retry on transient Stripe errors
  retry_on Stripe::RateLimitError, wait: :polynomially_longer, attempts: 3
  retry_on Stripe::APIConnectionError, wait: 5.seconds, attempts: 3

  # Discard if customer was deleted in Stripe
  discard_on Stripe::InvalidRequestError do |job, error|
    if error.message.include?("No such customer")
      user = User.find_by(id: job.arguments.first)
      user&.update_column(:stripe_customer_id, nil)
      Rails.logger.warn("Cleared stale stripe_customer_id for user #{job.arguments.first}")
    end
  end

  def perform(user_id, address_id = nil)
    user = User.find_by(id: user_id)
    unless user
      Rails.logger.info("StripeCustomerSyncJob: User #{user_id} not found, skipping sync")
      return
    end

    address = address_id ? Address.find_by(id: address_id) : user.default_address

    StripeCustomerSyncService.sync(user, address: address)
  end
end
