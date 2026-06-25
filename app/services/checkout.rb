module Checkout
  CART_ITEM_INCLUDES = [ :product, { design_attachment: :blob } ].freeze

  # Stripe completes a payment-mode session as "paid", or "no_payment_required"
  # when a discount (e.g. a 100%-off coupon) brings the total to 0. Both are
  # successful completions that must yield an order; only "unpaid" is rejected.
  COMPLETED_PAYMENT_STATUSES = %w[paid no_payment_required].freeze

  class MissingShippingDetails < StandardError; end
end
