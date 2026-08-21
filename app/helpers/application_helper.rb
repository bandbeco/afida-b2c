module ApplicationHelper
  # Client logos used for trust badges across the site
  CLIENT_LOGOS = [
    "ballie-ballerson.webp",
    "edwardian-hotels.svg",
    "hawksmoor.webp",
    "hurlingham.webp",
    "la-gelateria.webp",
    "mandarin-oriental.svg",
    "marriott.svg",
    "pixel-bar.webp",
    "royal-lancaster.svg",
    "the-grove.webp",
    "vincenzos.svg"
  ].freeze

  def client_logos
    CLIENT_LOGOS
  end

  def category_icon_path(category)
    icon_mapping = {
      "cups-and-lids" => "images/graphics/cold-cups.svg",
      "ice-cream-cups" => "images/graphics/ice-cream-cups.svg",
      "napkins" => "images/graphics/napkins.svg",
      "pizza-boxes" => "images/graphics/pizza-boxes.svg",
      "straws" => "images/graphics/straws.svg",
      "takeaway-containers" => "images/graphics/kraft-food-containers.svg",
      "takeaway-extras" => "images/graphics/take-away-extras.svg"
    }

    icon_mapping[category.slug]
  end

  # Returns the appropriate path for a product based on its type.
  # Branded products (customizable_template) link to /branded-products/:slug
  # Standard products link to /products/:slug
  def search_result_path(product)
    if product.customizable_template?
      branded_product_path(product)
    else
      product_path(product)
    end
  end

  # The free-shipping threshold formatted for display (e.g. "£100"), sourced
  # from Shipping::FREE_SHIPPING_THRESHOLD so copy never drifts from the real
  # (env-overridable) checkout threshold.
  def free_shipping_threshold_display
    Shipping.formatted_free_shipping_threshold
  end

  # The same threshold as a number, for the client-side countdown. Kept beside
  # the display version so both read the one checkout constant.
  def free_shipping_threshold_amount
    Shipping::FREE_SHIPPING_THRESHOLD.to_f
  end

  # The free-delivery claim, qualified by zone. Free delivery is a mainland
  # promise (ShippingZone::FREE_SHIPPING_ZONES), so the copy has to say so:
  # an unqualified claim is one we cannot keep for Northern Ireland, the
  # Highlands or the islands. Single source so the four templates that make
  # this claim cannot drift apart.
  def free_delivery_promise
    "Free delivery on mainland UK orders over #{free_shipping_threshold_display}"
  end

  # The nudge: the same promise, counted down against what the cart already
  # holds. The gap is the threshold minus the cart subtotal and nothing else.
  # What a product page is currently offering to add is not money the buyer has
  # spent, so it must never move this figure; an empty cart therefore has
  # nothing to count down from and gets the plain rule.
  #
  # Subtotal is products-only and excludes VAT, matching Shipping.free_shipping?
  # (see Cart#subtotal_amount). The claim stays mainland-qualified in every
  # state because no page rendering this knows the destination.
  def free_delivery_nudge(cart_subtotal)
    remaining = Shipping::FREE_SHIPPING_THRESHOLD - cart_subtotal.to_d

    return free_delivery_promise if cart_subtotal.to_d <= 0
    return "This order qualifies for free mainland UK delivery" if remaining <= 0

    "Add #{number_to_currency(remaining)} more for free mainland UK delivery"
  end

  # Marks the money figure inside a delivery sentence so it can be scanned at a
  # glance. Escapes the sentence first, then wraps the currency run, so this
  # stays safe for any string the nudge produces.
  def highlight_money(sentence)
    escaped = ERB::Util.html_escape(sentence)
    marked = escaped.to_str.sub(/£[\d,]+(?:\.\d{2})?/) do |amount|
      %(<span data-test="free-delivery-amount" class="text-success">#{amount}</span>)
    end
    marked.html_safe
  end

  # The companion caveat for the zones excluded from the promise above. States
  # the actual transit range rather than a vague "may take longer", and sources
  # it from ShippingZone so it can't drift from what the cart quotes.
  def non_mainland_delivery_note
    "Northern Ireland, the Scottish Highlands and offshore islands are charged " \
      "at a separate rate and take #{ShippingZone.transit_label(:highlands)}."
  end
end
