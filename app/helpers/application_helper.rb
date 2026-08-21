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
    subtotal = cart_subtotal.to_d
    return free_delivery_promise if subtotal <= 0
    return "This order qualifies for free mainland UK delivery" if free_delivery_qualified?(subtotal)

    # Rounded UP, and never below a penny. The gap can be a fraction of a penny
    # (cart_items.price is scale-4 and configured items divide a total by a
    # quantity), and rounding that to "Add £0.00 more" asks for nothing, while
    # rounding it away entirely would promise free delivery that checkout then
    # refuses. Asking for the penny that actually closes it is the only honest
    # option left.
    remaining = (Shipping::FREE_SHIPPING_THRESHOLD - subtotal).ceil(2)
    "Add #{number_to_currency(remaining)} more for free mainland UK delivery"
  end

  # Whether a cart has reached the threshold, decided EXACTLY as
  # Shipping.free_shipping? decides it. Deliberately unrounded: rounding here
  # would let the page promise free delivery for a cart a fraction of a penny
  # short, and checkout would then charge for it. A promise the buyer sees
  # broken at payment costs more than an awkward figure in the nudge.
  #
  # The hint partial tints itself from this, so the colour and the words are one
  # decision rather than two expressions of the same rule in two files.
  def free_delivery_qualified?(cart_subtotal)
    cart_subtotal.to_d >= Shipping::FREE_SHIPPING_THRESHOLD
  end

  # How far the cart has come toward the threshold, as a whole percent, for the
  # nudge's progress bar. Clamped to 0..100 because the value is rendered as a
  # width: past the threshold the bar is simply full, and a negative subtotal
  # must not invert it.
  #
  # Rounded DOWN rather than to nearest, so a cart a penny short reads 99 and
  # not a full bar beside the words "Add £0.01 more". That is the same rule
  # free_delivery_qualified? applies to the tint: nothing in this band may claim
  # a threshold the cart has not actually reached.
  def free_delivery_progress(cart_subtotal)
    subtotal = cart_subtotal.to_d
    return 0 if subtotal <= 0
    return 100 if free_delivery_qualified?(subtotal)

    ratio = subtotal / Shipping::FREE_SHIPPING_THRESHOLD * 100
    ratio.floor.clamp(0, 100)
  end

  # Marks the money figure inside a delivery sentence so it can be scanned at a
  # glance. Escapes the sentence first, then wraps the currency run, so this
  # stays safe for any string the nudge produces.
  #
  # success-CONTENT, not success. DaisyUI's `success` is the bright mint used
  # for the bar fill and the icon, and it measures 1.84:1 against the band's
  # near-white background: fine for a shape, under the 4.5:1 AA floor for text,
  # and this is the one word in the sentence a buyer actually scans for.
  # success-content is the same hue darkened, at 9.45:1.
  def highlight_money(sentence)
    escaped = ERB::Util.html_escape(sentence)
    marked = escaped.to_str.sub(/£[\d,]+(?:\.\d{2})?/) do |amount|
      %(<span data-test="free-delivery-amount" class="text-success-content">#{amount}</span>)
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
