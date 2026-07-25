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

  # Customer-facing transit wording, shown in the cart and carried in the Stripe
  # line-item name. Derived from TRANSIT_DAYS rather than written out per zone so
  # a zone can never be labelled next-day while its transit time says otherwise.
  #
  # These state the SAME number of days DeliveryEstimate adds, deliberately. DPD
  # quotes 2-4 days for HS/ZE/KW15-17, and we plan to the slow end (TRANSIT_DAYS
  # of 3, so 4 working days); labelling it "2-4 working days" while the order
  # confirmation states a single date at the far end of that range would have the
  # two promises contradict each other. Quote the date we actually commit to.
  TRANSIT_LABELS = {
    0 => "next working day",
    1 => "2 working days",
    3 => "4 working days"
  }.freeze

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

    # How long delivery takes to this zone, in customer-facing words.
    def transit_label(zone)
      days = transit_days(zone)
      TRANSIT_LABELS.fetch(days) { "#{days + 1} working days" }
    end

    # The zone's surcharge in pounds. Reached from Cart#cart_totals on every cart
    # and drawer render, so a malformed env override degrades to the default
    # rather than raising: a typo in SHIPPING_SURCHARGE_* must not take the
    # storefront down. The bad value is logged so it doesn't fail silently.
    def surcharge(zone)
      return BigDecimal("0") unless deliverable?(zone)

      default = DEFAULT_SURCHARGES.fetch(zone)
      configured = ENV.fetch("SHIPPING_SURCHARGE_#{zone.to_s.upcase}", default)

      begin
        BigDecimal(configured)
      rescue ArgumentError, TypeError
        Rails.logger.error(
          "[ShippingZone] SHIPPING_SURCHARGE_#{zone.to_s.upcase}=#{configured.inspect} is not a number; using #{default}"
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
