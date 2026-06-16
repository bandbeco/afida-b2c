# frozen_string_literal: true

# Subscribes to Rails.event events and routes them to Klaviyo (marketing ESP).
#
# Event → Klaviyo:
#   email_signup.completed        → "Subscribed" event (+ source)
#   email_signup.discount_claimed → "Claimed Discount" event
#   order.placed (normal/mixed)   → profile upsert (is_business, name) + "Placed Order" (with value)
#   order.placed (sample-only)    → profile upsert + "Requested Sample" (no value, not a purchase)
#
# checkout.started is intentionally NOT handled here: it carries no email at the
# point of emission (the customer enters their email on Stripe's hosted page),
# so there is no profile to attach. Abandoned-cart capture is a separate flow
# that triggers only once an email is known.
#
# Like DatafastSubscriber, this only enqueues background jobs; it never performs
# network I/O inline and never raises into the emitting business code.
#
# Usage (registered in config/initializers/events.rb):
#   Rails.event.subscribe(KlaviyoSubscriber.new)
class KlaviyoSubscriber
  def emit(event)
    case event[:name]
    when "email_signup.completed"
      handle_signup(event[:payload] || {})
    when "email_signup.discount_claimed"
      handle_discount_claimed(event[:payload] || {})
    when "order.placed"
      handle_order_placed(event[:payload] || {})
    end
  end

  private

  def handle_signup(payload)
    email = payload[:email]
    return if email.blank?

    # NOTE: payload[:discount_eligible] is deliberately not forwarded. The emitter
    # always sends it as true (ineligible signups bail out before the event fires),
    # so it carries no segmentation signal in Klaviyo. source IS meaningful.
    track("Subscribed", email, { source: payload[:source] }.compact)
  end

  def handle_discount_claimed(payload)
    email = payload[:email]
    return if email.blank?

    track("Claimed Discount", email, { discount_code: payload[:discount_code] }.compact)
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

  # Klaviyo profiles use separate first/last name fields. shipping_name is a
  # single string, so split on the first space and treat the remainder as surname.
  def split_name(full_name)
    return [ nil, nil ] if full_name.blank?

    first, rest = full_name.strip.split(" ", 2)
    [ first, rest ]
  end
end
