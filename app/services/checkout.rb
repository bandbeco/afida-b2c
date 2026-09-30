module Checkout
  CART_ITEM_INCLUDES = [ :product, { design_attachment: :blob } ].freeze

  # Stripe completes a payment-mode session as "paid", or "no_payment_required"
  # when a discount (e.g. a 100%-off coupon) brings the total to 0. Both are
  # successful completions that must yield an order; only "unpaid" is rejected.
  COMPLETED_PAYMENT_STATUSES = %w[paid no_payment_required].freeze

  # The two kinds of failure a checkout completion (see CONTEXT.md) can raise.
  # Callers act on the kind, never the cause: the webhook answers Stripe 200 to
  # a permanent failure (a retry can never succeed) and 5xx to a transient one
  # (so Stripe retries); the success redirect picks its flash copy by kind.
  #
  # Permanent: the same session will fail identically on every attempt.
  # Subclassed rather than wrapped so a caller can still pick copy by the
  # concrete class (MissingShippingDetails has its own customer message).
  class PermanentCompletionFailure < StandardError; end

  # A completed session carrying no shipping_details: the required shipping
  # fields would be nil, so the Order can never be valid.
  class MissingShippingDetails < PermanentCompletionFailure; end

  # A failure a retry may recover from: a Stripe hiccup, a database blip, an
  # item rollback that left no order behind. Wraps the cause (Exception#cause).
  class TransientCompletionFailure < StandardError; end
end
