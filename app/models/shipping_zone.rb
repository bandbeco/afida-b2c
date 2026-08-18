# Resolves a UK postcode to a delivery zone.
#
# Zones follow DPD UK's published "Our services in Scottish Highlands & Islands"
# table, because DPD is the carrier named on the delivery page and its UK
# network is the one that actually bills us. Local-authority boundaries
# correlate with it but are not the same thing, so they are not used here.
#
# That table is the ONLY source for the Scottish ranges. DPD publishes other
# regional surcharge lists for its European networks whose ranges differ; they
# describe different networks and must not be used to "correct" this table.
#
# The Scilly Isles (TR21-25), Northern Ireland (BT) and the Isle of Wight
# (PO30-41) are outside the Scottish table's scope; see their entries below.
#
# Boundaries are numeric, not alphabetic: AB31-56 is surcharged but AB10
# (Aberdeen city) is not, and PA20-78 is Argyll while PA1 (Paisley) is not. So
# the lookup key is the (area, district) pair, never the area letters alone.
#
# This is a pure function of the postcode string: no database, no network, no
# third-party dependency. Shipping must stay priceable when everything else is
# down, and a network call here would either block checkout or fail open to
# mainland pricing, which is the leak this class exists to close.
class ShippingZone
  ZONES = %i[mainland highlands remote_islands northern_ireland offshore_islands].freeze

  # Zones matched on the postcode area alone, where every district belongs.
  # HS and ZE are DPD UK's 2-4 Days rows (HS1-9, ZE1-3), which is every allocated
  # district in both areas. BT is outside the Scottish table's scope: Northern
  # Ireland is off-mainland by geography, not by a Scottish surcharge row.
  WHOLE_AREA_ZONES = {
    "BT" => :northern_ireland,
    "HS" => :remote_islands,
    "ZE" => :remote_islands
  }.freeze

  # Postcode areas we do not ship to at all: the Isle of Man and the Channel
  # Islands are Crown Dependencies, not GB, so Shipping::ALLOWED_COUNTRIES
  # refuses them at Stripe's address screen.
  #
  # They are named here rather than left to fall through to :mainland, which
  # would be the worst possible answer: the cart would quote £6.99 (or FREE over
  # the threshold) and checkout would build a Stripe session, so the customer
  # only discovered we don't ship there after clicking through to payment.
  # Resolving to :undeliverable instead means deliverable? is false, so the cart
  # never quotes a price and the checkout guard stops the order at the cart.
  UNDELIVERABLE_AREAS = %w[IM GY JE].freeze

  # Zones matched on an (area, district range) pair.
  #
  # The Scottish rows are DPD UK's table, with its Two Day rows mapped to
  # :highlands and its 2-4 Days rows to :remote_islands, so the zone carries the
  # service level DPD actually offers:
  #
  #   Aberdeen           AB31-AB35   Two Day     Argyll        PA20-PA78   Two Day
  #   Aberdeen           AB41-AB54   Two Day     Dundee        PH15-PH18   Two Day
  #   Northern Highlands AB36-AB38   Two Day     N. Highlands  PH19-PH29   Two Day
  #   Northern Highlands AB55-AB56   Two Day     Argyll        PH30-PH31   Two Day
  #   Argyll             FK17-FK21   Two Day     N. Highlands  PH32-PH33   Two Day
  #   Northern Highlands HS1-HS9     2-4 Days    Argyll        PH34-PH44   Two Day
  #   Northern Highlands IV1-IV63    Two Day     N. Highlands  PH45-PH48   Two Day
  #   Arran              KA27        Two Day     Argyll        PH49-PH50   Two Day
  #   Argyll             KA28        Two Day     Orkney/Shet.  ZE1-ZE3     2-4 Days
  #   Northern Highlands KW0-KW14    Two Day
  #   Orkney Shetland    KW15-KW17   2-4 Days
  #
  # Adjacent rows sharing a zone are merged (AB31-38 and AB41-56 rather than four
  # rows; PH15-50 rather than seven), since the Argyll/Highlands/Dundee labels
  # only name the depot and every one of those rows is Two Day. HS and ZE are
  # whole-area and live in WHOLE_AREA_ZONES.
  #
  # KW0-14 starts at 0: DPD writes KW0, and although Royal Mail allocates no KW0
  # today the range is transcribed as published rather than silently narrowed.
  DISTRICT_RANGE_ZONES = [
    [ "AB", 31..38, :highlands ],
    [ "AB", 41..56, :highlands ],
    [ "FK", 17..21, :highlands ],
    [ "IV",  1..63, :highlands ],
    [ "KA", 27..28, :highlands ],
    [ "KW",  0..14, :highlands ],
    [ "KW", 15..17, :remote_islands ],
    [ "PA", 20..78, :highlands ],
    [ "PH", 15..50, :highlands ],
    # Outside the Scottish table's scope, so sourced separately: the Isles of
    # Scilly are a 2-4 day sea/air crossing like the Scottish islands, and the
    # Isle of Wight is off-mainland per Afida leadership.
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
  #
  # This is deliberately SLOWER than DPD sells on the Highlands rows, which are
  # Two Day; only DPD's HS, ZE and KW15-17 rows are genuinely 2-4 days. Quoting
  # the slowest off-mainland service for every off-mainland zone keeps one simple
  # promise that the carrier beats rather than misses. Never "correct" this to
  # DPD's Two Day for the Highlands without changing the customer-facing copy
  # too: the label, the delivery page and the order's estimated date all derive
  # from here, and promising two days to Skye is a commitment we would then have
  # to keep at the carrier's pace.
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
    # The zone for a postcode: :unknown when it cannot be parsed, :undeliverable
    # for a place we do not ship to, or one of ZONES.
    #
    # Both non-ZONES answers are distinct from :mainland on purpose. Defaulting
    # either to mainland would quote the cheapest zone (and free delivery over
    # the threshold) for an address we either failed to understand or cannot
    # serve at all, so callers decide explicitly (see .deliverable?).
    def for(postcode)
      area, district = parse(postcode)
      return :unknown unless area
      return :undeliverable if UNDELIVERABLE_AREAS.include?(area)

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

    # The canonical form of a customer-typed postcode: uppercased, trimmed,
    # internal runs of spaces collapsed. This is what .for matches against and
    # what Checkout::CartFingerprint hashes, so "the same postcode" means the
    # same thing to the zone resolver and to the staleness fingerprint.
    def normalise(postcode)
      postcode.to_s.upcase.strip.squeeze(" ")
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

    # Why we refused a postcode, in the customer's terms. The two refusal
    # reasons get different messages because they are different problems: a
    # typo is worth retrying, whereas JE2 3AB is a perfectly valid postcode we
    # simply do not deliver to, and telling that customer we didn't recognise
    # it would send them round a loop that cannot succeed. Shared by the cart's
    # postcode field and the checkout page's live reprice so the two surfaces
    # can never explain the same refusal differently.
    def refusal_message(zone)
      if zone == :undeliverable
        "Sorry, we don't deliver to the Channel Islands or the Isle of Man."
      else
        "We didn't recognise that postcode. Please check it and try again."
      end
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
      normalised = normalise(postcode)
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
