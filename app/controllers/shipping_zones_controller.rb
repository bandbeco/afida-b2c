# The zone guard's server half: resolves a postcode to its shipping zone so the
# on-site checkout page can compare the address being typed against the zone
# the order was priced for. Read-only, session-free, public — it exposes
# nothing the delivery page doesn't already publish.
class ShippingZonesController < ApplicationController
  allow_unauthenticated_access

  def show
    zone = ShippingZone.for(params[:postcode])
    render json: { zone: zone, deliverable: ShippingZone.deliverable?(zone) }
  end
end
