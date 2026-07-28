module Checkout
  # Staleness fingerprint for a stashed on-site checkout session. The Stripe
  # session freezes line items and shipping price at #create; if the inputs
  # that produced them change before the GET page renders (cart edited in
  # another tab, postcode retyped, discount claimed), the stash must be
  # discarded rather than charged. Same inputs ⇒ same digest.
  class CartFingerprint
    def self.digest(cart:, postcode:, discount_code:)
      payload = {
        items: cart.cart_items.order(:id).map do |item|
          [ item.id, item.product_id, item.quantity, item.price.to_s, item.sample?, item.configuration ]
        end,
        postcode: postcode.to_s.upcase.strip.squeeze(" "),
        discount_code: discount_code.to_s
      }
      Digest::SHA256.hexdigest(payload.to_json)
    end
  end
end
