# Resolves a UK postcode to a delivery zone.
#
# Zones follow DPD's published Scottish Highlands & Islands table (DPD is the
# carrier named on the delivery page), because DPD's commercial boundary is the
# one that actually bills us. Local-authority boundaries correlate with it but
# are not the same thing, so they are deliberately not used here.
#
# Boundaries are numeric, not alphabetic: AB31-AB35 is surcharged but AB10
# (Aberdeen city) is not, and PH19-PH29 is Highlands while PH15-PH18 is
# Dundee-serviced. So the lookup key is the (area, district) pair, never the
# area letters alone.
#
# This is a pure function of the postcode string: no database, no network, no
# third-party dependency. Shipping must stay priceable when everything else is
# down, and a network call here would either block checkout or fail open to
# mainland pricing, which is the leak this class exists to close.
class ShippingZone
  ZONES = %i[mainland highlands remote_islands northern_ireland offshore_islands].freeze

  # Zones matched on the postcode area alone, where every district belongs.
  # Isle of Man (IM) and the Channel Islands (GY/JE) are absent deliberately:
  # they are not GB, so Shipping::ALLOWED_COUNTRIES already excludes them.
  WHOLE_AREA_ZONES = {
    "BT" => :northern_ireland,
    "HS" => :remote_islands,
    "ZE" => :remote_islands
  }.freeze

  # Zones matched on an (area, district range) pair, from DPD's table.
  DISTRICT_RANGE_ZONES = [
    [ "AB", 31..38, :highlands ],
    [ "AB", 41..56, :highlands ],
    [ "FK", 17..21, :highlands ],
    [ "IV",  1..63, :highlands ],
    [ "KA", 27..28, :highlands ],
    [ "KW",  1..14, :highlands ],
    [ "KW", 15..17, :remote_islands ],
    [ "PA", 20..78, :highlands ],
    [ "PH", 19..50, :highlands ],
    [ "PO", 30..41, :offshore_islands ],
    [ "TR", 21..25, :remote_islands ]
  ].freeze

  # Working days to add on top of the standard next-working-day dispatch.
  # DPD rates HS/ZE/KW15-17 at 2-4 days, so those cannot be sold as next-day at
  # any price. Mainland is the only zone that keeps the next-working-day promise.
  TRANSIT_DAYS = {
    mainland: 0,
    highlands: 1,
    northern_ireland: 1,
    offshore_islands: 1,
    remote_islands: 3
  }.freeze

  # Per-zone delivery surcharge in pounds, on top of Shipping::STANDARD_COST.
  #
  # PLACEHOLDER VALUES pending the DPD rate card. They are deliberately
  # non-zero so an un-updated deployment over-recovers rather than silently
  # absorbing the surcharge, which is the current bug. Override per zone with
  # SHIPPING_SURCHARGE_<ZONE>, e.g. SHIPPING_SURCHARGE_HIGHLANDS=12.50.
  DEFAULT_SURCHARGES = {
    mainland: "0",
    highlands: "12.50",
    northern_ireland: "12.50",
    offshore_islands: "12.50",
    remote_islands: "20.00"
  }.freeze

  # Zones where free delivery over the standard threshold still applies.
  # Mainland only by default: the free-shipping promise is a mainland promise,
  # which is what the site copy now says.
  FREE_SHIPPING_ZONES = %i[mainland].freeze

  class << self
    # The zone for a postcode, or :unknown when the postcode cannot be parsed.
    #
    # :unknown is distinct from :mainland on purpose. Defaulting unparseable
    # input to mainland would price the cheapest zone for an address we failed
    # to understand, so callers decide explicitly (see .deliverable?).
    def for(postcode)
      area, district = parse(postcode)
      return :unknown unless area

      return WHOLE_AREA_ZONES.fetch(area) if WHOLE_AREA_ZONES.key?(area)

      matched = DISTRICT_RANGE_ZONES.find do |range_area, districts, _zone|
        range_area == area && districts.cover?(district)
      end

      matched ? matched.last : :mainland
    end

    # Whether we ship to this zone at all. :unknown is not deliverable, so an
    # unparseable postcode is surfaced to the customer rather than mispriced.
    def deliverable?(zone)
      ZONES.include?(zone)
    end

    def transit_days(zone)
      TRANSIT_DAYS.fetch(zone, 0)
    end

    def surcharge(zone)
      return BigDecimal("0") unless deliverable?(zone)

      BigDecimal(ENV.fetch("SHIPPING_SURCHARGE_#{zone.to_s.upcase}", DEFAULT_SURCHARGES.fetch(zone)))
    end

    def free_shipping?(zone)
      FREE_SHIPPING_ZONES.include?(zone)
    end

    private

    # The (area, district) pair, or nil when the postcode is unparseable.
    # Reuses Address::UK_POSTCODE_REGEX so there is one definition of a valid UK
    # postcode; its first capture group is the outward code.
    def parse(postcode)
      normalised = postcode.to_s.upcase.strip
      match = Address::UK_POSTCODE_REGEX.match(normalised)
      return nil unless match

      outward = match[1]
      [ outward[/\A[A-Z]{1,2}/], outward[/[0-9]+/].to_i ]
    end
  end
end
