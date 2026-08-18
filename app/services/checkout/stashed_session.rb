# frozen_string_literal: true

module Checkout
  # Revalidates the stashed on-site checkout session against the cart as it
  # stands NOW: the Stripe session froze line items and shipping at #create,
  # so a stash that is expired, or whose fingerprint no longer matches the
  # re-resolved cart and destination, must be refused rather than charged.
  # Single home for the rules (and for deleting a dead stash) so GET /checkout
  # and PATCH /checkout can never drift apart on when a stash may be trusted -
  # they answer the same money question in different formats.
  class StashedSession
    # Stripe expires Checkout Sessions 24 hours after creation; past that the
    # stashed client_secret can only produce a dead page whose "please
    # refresh" advice re-serves the same expired secret. Bounce just short of
    # Stripe's line so the customer gets a working restart instead.
    TTL = 23.hours

    # states: :absent (no usable stash or nothing to sell - nothing deleted,
    # the stash may belong to a healthier context), :expired and :stale (stash
    # deleted here, the single home for that semantics), :valid.
    # items is the loaded cart_items set the fingerprint was computed from,
    # exposed so a caller writing a NEW fingerprint afterwards reuses it
    # instead of re-querying.
    Verdict = Struct.new(:state, :stash, :items, keyword_init: true) do
      def valid? = state == :valid
    end

    # session is the Rails session (read for the stash, written on delete);
    # postcode is the destination the caller re-resolved the way #create did -
    # trusting a postcode recorded in the stash instead would validate the
    # stash against itself.
    def self.revalidate(session:, cart:, postcode:, discount_code:)
      stash = session[:onsite_checkout]
      items = cart ? cart.cart_items.order(:id).to_a : []
      if stash.blank? || stash["session_id"].blank? || items.empty?
        return Verdict.new(state: :absent, stash: stash, items: items)
      end

      if stash["created_at"].to_i < TTL.ago.to_i
        session.delete(:onsite_checkout)
        return Verdict.new(state: :expired, items: items)
      end

      fingerprint = CartFingerprint.digest(
        cart: cart, postcode: postcode, discount_code: discount_code, items: items
      )
      if fingerprint != stash["fingerprint"]
        session.delete(:onsite_checkout)
        return Verdict.new(state: :stale, items: items)
      end

      Verdict.new(state: :valid, stash: stash, items: items)
    end
  end
end
