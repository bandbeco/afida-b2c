module Checkout
  # Staleness fingerprint for a stashed on-site checkout session. The Stripe
  # session freezes line items and shipping price at #create; if the inputs
  # that produced them change before the GET page renders (cart edited in
  # another tab, postcode retyped, discount claimed), the stash must be
  # discarded rather than charged. Same inputs ⇒ same digest.
  class CartFingerprint
    # items: pass an already-loaded `cart.cart_items.order(:id)` set when the
    # caller computes several digests per request (the reprice endpoint), so
    # each digest does not re-query; same records, same digest.
    def self.digest(cart:, postcode:, discount_code:, items: nil)
      payload = {
        items: (items || cart.cart_items.order(:id)).map do |item|
          [ item.id, item.product_id, item.quantity, item.price.to_s, item.sample?, item.configuration ]
        end,
        postcode: ShippingZone.normalise(postcode),
        discount_code: discount_code.to_s
      }
      Digest::SHA256.hexdigest(payload.to_json)
    end
  end
end
