# frozen_string_literal: true

# Subscribes to Rails.event events and routes them to Klaviyo (marketing ESP).
#
# Event → Klaviyo:
#   email_signup.completed        → "Subscribed" event (+ source)
#   email_signup.discount_claimed → "Claimed Discount" event
#   cart.checkout_initiated       → "Started Checkout" event (with cart total as value)
#   order.placed (normal/mixed)   → profile upsert (is_business, name) + "Placed Order" (with value)
#   order.placed (sample-only)    → profile upsert + "Requested Sample" (no value, not a purchase)
#
# checkout.started is intentionally NOT handled here: it carries no email at the
# point of emission (the customer enters their email on Stripe's hosted page),
# so there is no profile to attach. Abandoned-cart capture rides on
# cart.checkout_initiated instead, which the discount-signup flow emits once an
# email IS known. Like order.placed, the cart is reloaded by id; the abandoned-
# cart delay and suppression ("Placed Order zero times") live in a Klaviyo Flow,
# so no scheduling or suppression logic lives here.
#
# Email handling: Rails.event filters payload values whose keys match
# config.filter_parameters (by substring), and :email is one of them, so
# payload[:email] arrives as "[FILTERED]". Every handler therefore resolves the
# real address from a record (EmailSubscription via subscription_id, or Order via
# order_id), never from the payload. The id key avoids the "email" substring so
# the filter does not redact it too.
#
# Like DatafastSubscriber, this only enqueues background jobs; it never performs
# network I/O inline and never raises into the emitting business code.
#
# Usage (registered in config/initializers/events.rb):
#   Rails.event.subscribe(KlaviyoSubscriber.new)
class KlaviyoSubscriber
  # Most line items to serialize into a "Started Checkout" payload (see
  # handle_checkout_initiated).
  MAX_ITEMS_IN_PAYLOAD = 20

  def emit(event)
    case event[:name]
    when "email_signup.completed"
      handle_signup(event[:payload] || {})
    when "email_signup.discount_claimed"
      handle_discount_claimed(event[:payload] || {})
    when "cart.checkout_initiated"
      handle_checkout_initiated(event[:payload] || {})
    when "order.placed"
      handle_order_placed(event[:payload] || {})
    end
  end

  private

  def handle_signup(payload)
    email = subscription_email(payload)
    return if email.blank?

    # NOTE: payload[:discount_eligible] is deliberately not forwarded. The emitter
    # always sends it as true (ineligible signups bail out before the event fires),
    # so it carries no segmentation signal in Klaviyo. source IS meaningful.
    track("Subscribed", email, { source: payload[:source] }.compact)
  end

  def handle_discount_claimed(payload)
    order = Order.find_by(id: payload[:order_id])
    return if order.nil? || order.email.blank?

    track("Claimed Discount", order.email, { discount_code: payload[:discount_code] }.compact)
  end

  # Abandoned-cart trigger. The discount-signup flow emits this once an email is
  # known and Current.cart has items. We resolve the email from the EmailSubscription
  # (payload[:email] is filtered out by Rails.event) and reload the cart for its
  # line items (one query, products eager-loaded), then send Klaviyo a "Started
  # Checkout" metric with the cart total as value plus a signed cross-device
  # recovery link. Klaviyo's Flow owns the delay and "Placed Order zero times"
  # suppression.
  def handle_checkout_initiated(payload)
    email = subscription_email(payload)
    return if email.blank?

    cart = Cart.find_by(id: payload[:cart_id])
    return unless cart

    # Cap the serialized line items: they ride in both the Klaviyo payload and the
    # persisted Solid Queue job args, and a large B2B cart has many lines. The
    # email template rarely renders more, and item_count/line_items_count still
    # carry the true totals.
    line_items = cart.cart_items.includes(:product).limit(MAX_ITEMS_IN_PAYLOAD)
    items = line_items.map do |item|
      { name: item.product.name, quantity: item.quantity, price: item.price.to_f }
    end
    return if items.empty?

    properties = {
      item_count: cart.items_count,
      line_items_count: cart.line_items_count,
      items: items,
      checkout_url: cart.recovery_url
    }

    track("Started Checkout", email, properties, value: cart.total_amount.to_f)
  end

  def handle_order_placed(payload)
    # One indexed primary-key lookup in the request thread. The order.placed
    # payload only carries order_id, and Klaviyo needs the order's attributes
    # (email, name, b2b/sample flags, total). Cheap and bounded; the network
    # I/O is deferred to the enqueued job.
    order = Order.find_by(id: payload[:order_id])
    return unless order

    # For B2B orders shipping_name is often a company name, so splitting it into
    # first/last produces nonsense. Leave the name fields blank for businesses.
    first_name, last_name = order.b2b_order? ? [ nil, nil ] : split_name(order.shipping_name)

    sample_request = order.sample_request?

    KlaviyoEventJob.perform_later(
      "upsert_profile",
      email: order.email,
      first_name: first_name,
      last_name: last_name,
      properties: {
        is_business: order.b2b_order?,
        sample_request: sample_request
      }
    )

    properties = {
      order_number: order.order_number,
      item_count: order.items_count,
      is_business: order.b2b_order?,
      sample_request: sample_request
    }

    if sample_request
      # A sample-only order is a free trial, not a purchase. Use a distinct metric
      # and omit value so the order total (shipping only) never counts as revenue
      # in Klaviyo's Placed Order reporting.
      track("Requested Sample", order.email, properties)
    else
      track("Placed Order", order.email, properties, value: order.total_amount.to_f)
    end
  end

  def track(metric, email, properties, value: nil)
    args = { metric: metric, email: email, properties: properties }
    args[:value] = value unless value.nil?
    KlaviyoEventJob.perform_later("track", **args)
  end

  # Resolves the profile email from the EmailSubscription record rather than the
  # payload: Rails.event filters :email (it is in config.filter_parameters), so
  # payload[:email] arrives as "[FILTERED]". Mirrors how handle_order_placed reads
  # Order#email from order_id instead of trusting the payload. The id key is
  # "subscription_id" (not "email_subscription_id") because the filter matches by
  # substring and would otherwise redact any key containing "email" too.
  def subscription_email(payload)
    EmailSubscription.find_by(id: payload[:subscription_id])&.email
  end

  # Klaviyo profiles use separate first/last name fields. shipping_name is a
  # single string, so split on the first space and treat the remainder as surname.
  def split_name(full_name)
    return [ nil, nil ] if full_name.blank?

    first, rest = full_name.strip.split(" ", 2)
    [ first, rest ]
  end
end
