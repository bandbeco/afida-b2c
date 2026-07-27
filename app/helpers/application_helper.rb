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

  # The companion caveat for the zones excluded from the promise above. States
  # the actual transit range rather than a vague "may take longer", and sources
  # it from ShippingZone so it can't drift from what the cart quotes.
  def non_mainland_delivery_note
    "Northern Ireland, the Scottish Highlands and offshore islands are charged " \
      "at a separate rate and take #{ShippingZone.transit_label(:highlands)}."
  end

  # A ShippingZone in the customer's words, for the cart's delivery calculator.
  # The zone symbols are carrier vocabulary; these are what a customer would
  # recognise as the place they live.
  # remote_islands spans the Scottish islands AND the Isles of Scilly (TR21-25,
  # Cornwall), so it cannot be named "the Scottish islands" without telling a St
  # Mary's customer they live in Scotland. offshore_islands is PO30-41 today but
  # is named for the zone, not the one area in it, so adding another island
  # doesn't silently make the copy wrong.
  DELIVERY_ZONE_NAMES = {
    mainland: "mainland UK",
    highlands: "the Scottish Highlands",
    remote_islands: "the Scottish and Scilly isles",
    northern_ireland: "Northern Ireland",
    offshore_islands: "the offshore islands"
  }.freeze

  def delivery_zone_name(zone)
    DELIVERY_ZONE_NAMES.fetch(zone, "your area")
  end

  # Whether we know where this cart is going well enough to price it, which is
  # what CheckoutsController requires before it will build a Stripe session.
  # Checks the entered postcode rather than the cart's zone, because the zone
  # falls back to mainland by design and so is never "unknown".
  #
  # address_postcode is the postcode of the address the customer has SELECTED
  # (nil when none is). It must be the selected one, not merely one they have on
  # file: the controller resolves the selected address_id, so gating on "has any
  # saved address" would enable a button that checkout then refuses, bouncing the
  # customer between the cart and the guard forever.
  def delivery_destination_known?(cart, address_postcode: nil)
    return true if ShippingZone.deliverable?(ShippingZone.for(address_postcode))

    ShippingZone.deliverable?(ShippingZone.for(cart&.delivery_postcode))
  end

  # The saved-address postcode that stands in for "where this customer usually
  # ships", used to decide whether checkout can be offered without typing.
  #
  # Checks the cart's owner first and Current.user second, because neither alone
  # covers every surface: pages calling allow_unauthenticated_access (products,
  # collections, the price list) skip resume_session, so Current.user is nil
  # there; and a signed-in customer can still be holding a guest cart, since
  # set_current_cart only binds a user cart when Current.user is set. Taking
  # either keeps the drawer and the cart page at the same verdict.
  def cart_owner_default_postcode(cart)
    owner = cart&.user || Current.user
    owner&.addresses&.default_first&.first&.postcode
  end
end
