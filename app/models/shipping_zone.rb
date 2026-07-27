# Resolves a UK postcode to a delivery zone.
#
# Zones are transcribed from DPD's published "Islands and regions subject to
# surcharge" list (DPD CLASSIC & DPD EXPRESS, edition 06/2020), because DPD is
# the carrier named on the delivery page and its commercial boundary is the one
# that actually bills us. Local-authority boundaries correlate with it but are
# not the same thing, so they are deliberately not used here.
#
# The GB row of that list, verbatim:
#   Northern Ireland: BT, Channel Islands Guernsey and Jersey: GY, JE, Outer
#   Hebrides: HS, Isle of Man: IM, Scottish Highlands and Isle of Skye: IV,
#   Orkney Inseln: KW, Shetland Islands: ZE, Firth of Clyde Islands: KA27-28,
#   Region Argyll and Bute with Loch Lomond and Inner Hebrides: FK17-21,
#   PA20-38, PA41-49, PA60-80, PH16-50, Isle of Wight: PO30-41,
#   Isles of Scilly: TR21-25
#
# Boundaries are numeric, not alphabetic, and the ranges are NOT contiguous:
# PA39-40 and PA50-59 fall in gaps between the listed Argyll bands and take the
# standard rate, while PA38 and PA41 either side of them do not. So the lookup
# key is the (area, district) pair, never the area letters alone.
#
# Aberdeenshire (AB) does not appear on the list at any district and is
# therefore mainland throughout, despite being geographically remote.
#
# This is a pure function of the postcode string: no database, no network, no
# third-party dependency. Shipping must stay priceable when everything else is
# down, and a network call here would either block checkout or fail open to
# mainland pricing, which is the leak this class exists to close.
class ShippingZone
  ZONES = %i[mainland highlands remote_islands northern_ireland offshore_islands].freeze

  # Zones matched on the postcode area alone, where every district belongs.
  #
  # Isle of Man (IM) and the Channel Islands (GY/JE) are on DPD's list but absent
  # here deliberately: they are not GB, so Shipping::ALLOWED_COUNTRIES already
  # refuses them at checkout and they can never reach this lookup.
  #
  # IV is on DPD's list as a whole area but is handled in DISTRICT_RANGE_ZONES
  # instead, because IV1-63 covers every allocated district anyway and keeping it
  # numeric documents that.
  WHOLE_AREA_ZONES = {
    "BT" => :northern_ireland,
    "HS" => :remote_islands,
    "ZE" => :remote_islands
  }.freeze

  # Zones matched on an (area, district range) pair, from DPD's list.
  #
  # The three PA bands are deliberately separate entries rather than one 20..80
  # range: DPD lists PA20-38, PA41-49 and PA60-80, leaving PA39-40 and PA50-59
  # unlisted and therefore standard-rate. Collapsing them would surcharge those
  # gaps wrongly.
  #
  # KW is split by service level, not by DPD's list, which gives the whole area:
  # Orkney (KW15-17) is a genuine island crossing, so it takes the slower
  # remote-islands zone while the Caithness mainland (KW1-14) does not. Both are
  # off-mainland and priced alike, so the split only affects the transit promise.
  DISTRICT_RANGE_ZONES = [
    [ "FK", 17..21, :highlands ],
    [ "IV",  1..63, :highlands ],
    [ "KA", 27..28, :highlands ],
    [ "KW",  1..14, :highlands ],
    [ "KW", 15..17, :remote_islands ],
    [ "PA", 20..38, :highlands ],
    [ "PA", 41..49, :highlands ],
    [ "PA", 60..80, :highlands ],
    [ "PH", 16..50, :highlands ],
    [ "PO", 30..41, :offshore_islands ],
    [ "TR", 21..25, :remote_islands ]
  ].freeze

  # Working days to add on top of the standard next-working-day dispatch.
  #
  # Afida leadership set ONE off-mainland service level: 2-4 working days
  # everywhere off the mainland, rather than a per-zone transit time. We quote
  # that range (see TRANSIT_LABELS) but plan to its slow end, so a parcel that
  # arrives early is a good surprise while one taking the full four days still
  # meets the promise. Mainland is the only zone that keeps next-working-day.
  OFF_MAINLAND_TRANSIT_DAYS = 3

  TRANSIT_DAYS = {
    mainland: 0,
    highlands: OFF_MAINLAND_TRANSIT_DAYS,
    northern_ireland: OFF_MAINLAND_TRANSIT_DAYS,
    offshore_islands: OFF_MAINLAND_TRANSIT_DAYS,
    remote_islands: OFF_MAINLAND_TRANSIT_DAYS
  }.freeze

  # The whole delivery charge in pounds for an off-mainland zone.
  #
  # This REPLACES Shipping::STANDARD_COST rather than adding to it: Afida
  # leadership quoted £25 off-mainland as the total the customer pays, not as a
  # surcharge on top of the £6.99 mainland rate. Mainland has no entry here and
  # falls through to STANDARD_COST, which stays the single definition of the
  # mainland price.
  #
  # ONE off-mainland figure, not a per-zone tier: the only granularity needed is
  # mainland vs off-mainland, so every off-mainland zone is charged alike (as
  # they are already promised alike, see TRANSIT_DAYS).
  #
  # PER ORDER, not per case, by decision: this figure is charged once however
  # many cases the order contains. The carrier bills us per case, so a bulk
  # off-mainland order under-recovers by design; Afida leadership chose the
  # simpler pricing over full recovery for now. Moving to per-case pricing means
  # multiplying by the case count, not editing this constant, so keep the two
  # questions separate. Override per zone with SHIPPING_COST_<ZONE>, e.g.
  # SHIPPING_COST_HIGHLANDS=25.
  OFF_MAINLAND_COST = "25.00"

  DEFAULT_COSTS = {
    highlands: OFF_MAINLAND_COST,
    northern_ireland: OFF_MAINLAND_COST,
    offshore_islands: OFF_MAINLAND_COST,
    remote_islands: OFF_MAINLAND_COST
  }.freeze

  # Zones where free delivery over the standard threshold still applies.
  #
  # Mainland only, confirmed by Afida leadership: there is no free shipping
  # off-mainland at any order value. The carrier charges us off-mainland per
  # case, so a large order costs MORE to ship, not less; waiving delivery on it
  # would lose more the bigger the order got. This is what the site copy says.
  FREE_SHIPPING_ZONES = %i[mainland].freeze

  # Customer-facing transit wording, shown in the cart and carried in the Stripe
  # line-item name.
  #
  # Off-mainland quotes the 2-4 day RANGE while DeliveryEstimate stamps a single
  # date planned to day 4. The two are deliberately not the same shape: the range
  # is what we advertise, the date is what we commit to, and the date sits inside
  # the range so a customer reading both is never told two contradicting things.
  MAINLAND_TRANSIT_LABEL = "next working day"
  OFF_MAINLAND_TRANSIT_LABEL = "2-4 working days"

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

    # Working days on top of the standard next-working-day dispatch.
    #
    # An undeliverable zone falls to the SLOWEST transit rather than 0. Defaulting
    # to 0 would sell an address we could not identify as next working day, which
    # is a promise made on no information; erring slow is the safe direction for a
    # delivery commitment. Callers normalise to mainland before pricing, so this
    # is a fail-safe rather than a live path.
    def transit_days(zone)
      return TRANSIT_DAYS.values.max unless deliverable?(zone)

      TRANSIT_DAYS.fetch(zone)
    end

    # How long delivery takes to this zone, in customer-facing words. Keyed off
    # transit_days so an undeliverable zone (which falls to the slowest transit)
    # can never be labelled next working day.
    def transit_label(zone)
      transit_days(zone).zero? ? MAINLAND_TRANSIT_LABEL : OFF_MAINLAND_TRANSIT_LABEL
    end

    # The zone's whole delivery charge in pounds, or nil for a zone that has no
    # price of its own and so takes Shipping::STANDARD_COST (mainland, and any
    # undeliverable zone, which callers normalise to mainland before pricing).
    #
    # Reached from Cart#cart_totals on every cart and drawer render, so a
    # malformed env override degrades to the default rather than raising: a typo
    # in SHIPPING_COST_* must not take the storefront down. The bad value is
    # logged so it doesn't fail silently.
    def delivery_cost(zone)
      default = DEFAULT_COSTS[zone]
      return nil unless default

      configured = ENV.fetch("SHIPPING_COST_#{zone.to_s.upcase}", default)

      begin
        BigDecimal(configured)
      rescue ArgumentError, TypeError
        Rails.logger.error(
          "[ShippingZone] SHIPPING_COST_#{zone.to_s.upcase}=#{configured.inspect} is not a number; using #{default}"
        )
        BigDecimal(default)
      end
    end

    def free_shipping?(zone)
      FREE_SHIPPING_ZONES.include?(zone)
    end

    private

    # An outward code on its own, e.g. "IV51" or "BT1". The zone lookup needs
    # nothing more than this, and it is what a customer naturally types into a
    # "calculate delivery" field, so accepting it avoids telling them their real
    # postcode wasn't recognised. Mirrors the outward-code group in
    # Address::UK_POSTCODE_REGEX, anchored so partial junk still fails.
    OUTWARD_CODE_REGEX = /\A[A-Z]{1,2}[0-9][0-9A-Z]?\z/

    # The (area, district) pair, or nil when the postcode is unparseable.
    # Accepts a full postcode (via Address::UK_POSTCODE_REGEX, so there is one
    # definition of a valid UK postcode) or an outward code alone.
    def parse(postcode)
      normalised = postcode.to_s.upcase.strip
      outward = outward_code(normalised)
      return nil unless outward

      [ outward[/\A[A-Z]{1,2}/], outward[/[0-9]+/].to_i ]
    end

    def outward_code(normalised)
      match = Address::UK_POSTCODE_REGEX.match(normalised)
      return match[1] if match

      normalised if OUTWARD_CODE_REGEX.match?(normalised)
    end
  end
end
