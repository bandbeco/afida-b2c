# The zone guard's server half: resolves a postcode to its shipping zone so the
# on-site checkout page can compare the address being typed against the zone
# the order was priced for. Read-only and public; it exposes nothing the
# delivery page doesn't already publish. Skips the storefront chrome (cart
# resolution, nav queries): the route sits outside checkout's rate limit, so a
# cookieless client hammering it must not mint an orphan Cart row per hit.
class ShippingZonesController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :set_current_cart, :set_nav_categories

  def show
    zone = ShippingZone.for(params[:postcode])
    render json: { zone: zone, deliverable: ShippingZone.deliverable?(zone) }
  end
end
