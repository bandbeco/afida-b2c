# Syncs user information with Stripe Customer objects.
# Creates a Stripe Customer if one doesn't exist, and updates shipping address
# when the user's default address changes.
#
# This enables address prefill at Stripe Checkout by using the `customer` parameter
# instead of `customer_email`.
#
# Usage:
#   StripeCustomerSyncService.sync(user)                    # Sync user with default address
#   StripeCustomerSyncService.sync(user, address: address)  # Sync user with specific address
#
class StripeCustomerSyncService
  class << self
    # Syncs user with Stripe Customer, creating if necessary.
    # Returns the Stripe Customer ID.
    def sync(user, address: nil)
      new(user, address: address).sync
    end
  end

  def initialize(user, address: nil)
    @user = user
    @address = address || user.default_address
  end

  def sync
    if @user.stripe_customer_id.present?
      update_existing_customer
    else
      create_new_customer
    end

    @user.stripe_customer_id
  rescue Stripe::StripeError => e
    Rails.logger.error("Stripe customer sync failed for user #{@user.id}: #{e.message}")
    raise
  end

  private

  def create_new_customer
    params = build_customer_params.merge(metadata: { user_id: @user.id })
    customer = Stripe::Customer.create(params)
    @user.update!(stripe_customer_id: customer.id)

    Rails.logger.info("Created Stripe customer #{customer.id} for user #{@user.id}")
  end

  def update_existing_customer
    Stripe::Customer.update(@user.stripe_customer_id, build_customer_params)

    Rails.logger.info("Updated Stripe customer #{@user.stripe_customer_id} for user #{@user.id}")
  end

  def build_customer_params
    params = {
      email: @user.email_address,
      name: @user.first_name.present? ? "#{@user.first_name} #{@user.last_name}".strip : nil,
      shipping: @address.present? ? build_shipping_params : nil
    }
    params.compact
  end

  def build_shipping_params
    {
      name: @address.recipient_name,
      phone: @address.phone.presence,
      address: {
        line1: @address.line1,
        line2: @address.line2.presence,
        city: @address.city,
        postal_code: @address.postcode,
        country: @address.country
      }.compact
    }.compact
  end
end
