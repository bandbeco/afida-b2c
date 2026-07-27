require "test_helper"

class ShippingZoneTest < ActiveSupport::TestCase
  # Zone boundaries follow DPD's published Scottish Highlands & Islands table,
  # the carrier named on the delivery page. Boundaries are numeric, not
  # alphabetic, so each surcharged range is tested against its mainland
  # neighbour in the same postcode area.

  test "ordinary mainland postcodes are mainland" do
    %w[SW1A\ 1AA M1\ 1AA WD18\ 9SB B29\ 6AE LS10\ 1GE G20\ 6AG CF82\ 7DU].each do |postcode|
      assert_equal :mainland, ShippingZone.for(postcode), "expected #{postcode} to be mainland"
    end
  end

  test "northern ireland is matched on the whole BT area" do
    assert_equal :northern_ireland, ShippingZone.for("BT1 6EE")
    assert_equal :northern_ireland, ShippingZone.for("BT25 1JX")
    assert_equal :northern_ireland, ShippingZone.for("BT61 8HE")
  end

  test "highlands ranges are matched" do
    {
      "FK17 8AA" => "Argyll",
      "IV1 1AA" => "Inverness",
      "IV51 9YB" => "Skye",
      "IV63 7AA" => "Loch Ness",
      "KA27 8AA" => "Arran",
      "KA28 0AA" => "Cumbrae",
      "KW1 4AA" => "Wick",
      "KW14 7AA" => "Thurso",
      "AB31 4AA" => "Banchory",
      "AB37 9AA" => "Tomintoul",
      "AB45 1AA" => "Banff",
      "AB55 4AA" => "Keith",
      "PA20 0AA" => "Bute",
      "PA39 4AA" => "Ardgour, inside the PA20-78 band",
      "PA50 6AA" => "Islay, inside the PA20-78 band",
      "PA78 6AA" => "Tiree",
      "PH15 2AA" => "Aberfeldy, the first surcharged PH district",
      "PH18 5AA" => "Blair Atholl",
      "PH19 1AA" => "Dalwhinnie",
      "PH33 6AA" => "Fort William",
      "PH41 4AA" => "Mallaig",
      "PH50 4AA" => "Kinlochleven"
    }.each do |postcode, place|
      assert_equal :highlands, ShippingZone.for(postcode), "expected #{postcode} (#{place}) to be highlands"
    end
  end

  # PA20-78 is ONE band on DPD UK's table, so the whole of Argyll is surcharged
  # with no standard-rate gaps inside it. PA79-80 sit above the range and are
  # not on the table.
  test "the argyll range is continuous from PA20 to PA78" do
    (20..78).each do |district|
      assert_equal :highlands, ShippingZone.for("PA#{district} 1AA"),
                   "PA#{district} is inside DPD's PA20-PA78 band"
    end
  end

  # Aberdeenshire IS surcharged, at AB31-38 and AB41-56, despite AB10 (Aberdeen
  # city) sitting in the same postcode area at the standard rate. This is the
  # clearest case for matching on the (area, district) pair.
  test "aberdeenshire is surcharged above the city districts" do
    {
      "AB31 4AA" => "Banchory",
      "AB35 5AA" => "Ballater",
      "AB37 9AA" => "Tomintoul",
      "AB41 6AA" => "Ellon",
      "AB45 1AA" => "Banff",
      "AB55 4AA" => "Keith",
      "AB56 1AA" => "top of the area"
    }.each do |postcode, place|
      assert_equal :highlands, ShippingZone.for(postcode), "expected #{postcode} (#{place}) to be highlands"
    end
  end

  test "remote islands are the 2-4 day zones" do
    {
      "HS1 2DD" => "Stornoway",
      "HS9 5AA" => "Barra",
      "ZE1 0AA" => "Lerwick",
      "ZE3 9AA" => "Sumburgh",
      "KW15 1AA" => "Kirkwall, Orkney",
      "KW17 2AA" => "Orkney isles",
      "TR21 0AA" => "St Mary's, Scilly",
      "TR25 0AA" => "Scilly"
    }.each do |postcode, place|
      assert_equal :remote_islands, ShippingZone.for(postcode), "expected #{postcode} (#{place}) to be remote_islands"
    end
  end

  test "isle of wight is an offshore island" do
    assert_equal :offshore_islands, ShippingZone.for("PO30 1AA")
    assert_equal :offshore_islands, ShippingZone.for("PO41 0AA")
  end

  test "the isle of wight is priced and promised as off-mainland" do
    # On DPD's list as PO30-41 and confirmed by Afida leadership. Pin the
    # consequence rather than just the label: the island pays the off-mainland
    # rate, never ships free, and is not sold next working day.
    assert_equal Shipping.cost_for_zone_in_pounds(:highlands),
                 Shipping.cost_for_zone_in_pounds(:offshore_islands)
    assert_not ShippingZone.free_shipping?(:offshore_islands)
    assert_equal ShippingZone::OFF_MAINLAND_TRANSIT_LABEL,
                 ShippingZone.transit_label(:offshore_islands)
  end

  test "portsmouth and southampton stay mainland either side of the island" do
    # The PO range is numeric: a false off-mainland match here would charge
    # ordinary south-coast customers the island rate.
    assert_equal Shipping.standard_cost_in_pounds, Shipping.cost_for_zone_in_pounds(:mainland).to_f
    assert_equal :mainland, ShippingZone.for("PO29 9ZZ")
    assert_equal :mainland, ShippingZone.for("PO42 0AA")
  end

  # The near-miss cases: same postcode area as a surcharged range but a district
  # number outside it. Matching on area letters alone would wrongly surcharge
  # these, and KA1, PH2, TR8 and TR26 all appear in real production orders.
  test "mainland districts sharing an area with a surcharged range stay mainland" do
    {
      "AB10 1AA" => "Aberdeen city vs AB31-56",
      "AB25 1AA" => "Aberdeen city vs AB31-56",
      "AB39 3AA" => "Stonehaven, in the AB38/AB41 gap",
      "FK1 1AA" => "Falkirk vs FK17-21",
      "KA1 1UR" => "Kilmarnock vs KA27-28",
      "KW18 1AA" => "above the KW range",
      "PA1 1AA" => "Paisley vs PA20-78",
      "PA79 6AA" => "above the PA20-78 band",
      "PH1 1AA" => "Perth vs PH15-50",
      "PH2 6FB" => "Perth vs PH15-50",
      "PH14 9AA" => "just below the PH15 boundary",
      "PO1 1AA" => "Portsmouth vs PO30-41",
      "PO50 1AA" => "above the Isle of Wight range",
      "TR8 4AB" => "Cornwall mainland vs TR21-25",
      "TR26 3HA" => "St Ives vs TR21-25"
    }.each do |postcode, why|
      assert_equal :mainland, ShippingZone.for(postcode), "expected #{postcode} to be mainland (#{why})"
    end
  end

  # DPD UK's "Our services in Scottish Highlands & Islands" table, transcribed
  # row for row as the source of truth, with its Service column preserved.
  # Pinning the whole table rather than sampled postcodes means a future edit to
  # the zone table is checked against the carrier's document, not against
  # whichever examples happened to be in the other tests.
  #
  # This covers Scotland only. BT, PO and TR are sourced separately (see the
  # tests for each) and are deliberately not asserted against this table.
  DPD_UK_SCOTLAND = [
    [ "AB", 31..35, "Two Day" ],
    [ "AB", 41..54, "Two Day" ],
    [ "AB", 36..38, "Two Day" ],
    [ "AB", 55..56, "Two Day" ],
    [ "FK", 17..21, "Two Day" ],
    [ "HS",  1..9,  "2-4 Days" ],
    [ "IV",  1..63, "Two Day" ],
    [ "KA", 27..27, "Two Day" ],
    [ "KA", 28..28, "Two Day" ],
    [ "KW",  0..14, "Two Day" ],
    [ "KW", 15..17, "2-4 Days" ],
    [ "PA", 20..78, "Two Day" ],
    [ "PH", 15..18, "Two Day" ],
    [ "PH", 19..29, "Two Day" ],
    [ "PH", 32..33, "Two Day" ],
    [ "PH", 45..48, "Two Day" ],
    [ "PH", 30..31, "Two Day" ],
    [ "PH", 34..44, "Two Day" ],
    [ "PH", 49..50, "Two Day" ],
    [ "ZE",  1..3,  "2-4 Days" ]
  ].freeze

  # Highest allocated district per area (Royal Mail), so the sweep below asks
  # only about postcodes that can exist.
  SCOTTISH_ALLOCATED_DISTRICTS = {
    "AB" => 56, "FK" => 21, "HS" => 9, "IV" => 63, "KA" => 30,
    "KW" => 17, "PA" => 80, "PH" => 50, "ZE" => 3
  }.freeze

  test "every Scottish district matches DPD UK's published table" do
    mismatches = SCOTTISH_ALLOCATED_DISTRICTS.flat_map do |area, highest|
      (1..highest).filter_map do |district|
        row = dpd_uk_row(area, district)
        zone = ShippingZone.for("#{area}#{district}")
        next if row.nil? == (zone == :mainland)

        "#{area}#{district}: DPD says #{row ? "surcharged" : "standard rate"}, we say #{zone}"
      end
    end

    assert_empty mismatches, "zone table disagrees with DPD UK:\n  #{mismatches.join("\n  ")}"
  end

  test "DPD's 2-4 day rows are the remote-island zones and its Two Day rows are not" do
    # The Service column is the reason remote_islands exists as a separate zone:
    # HS, ZE and Orkney (KW15-17) are a slower crossing than the Two Day
    # mainland-Highlands rows, and quoting them alike would promise Stornoway a
    # service DPD does not sell.
    SCOTTISH_ALLOCATED_DISTRICTS.each do |area, highest|
      (1..highest).each do |district|
        row = dpd_uk_row(area, district)
        next unless row

        zone = ShippingZone.for("#{area}#{district}")
        if row.last == "2-4 Days"
          assert_equal :remote_islands, zone, "#{area}#{district} is a 2-4 day row"
        else
          assert_equal :highlands, zone, "#{area}#{district} is a Two Day row"
        end
      end
    end
  end

  test "handles messy real-world input" do
    # Bt618he is a real production postcode: no space, mixed case.
    assert_equal :northern_ireland, ShippingZone.for("Bt618he")
    assert_equal :highlands, ShippingZone.for("iv51 9yb")
    assert_equal :remote_islands, ShippingZone.for("  HS1  2DD  ")
    assert_equal :mainland, ShippingZone.for("SW38YU")
  end

  test "unparseable input is unknown rather than silently mainland" do
    [ "", "   ", nil, "not a postcode", "12345", "XX" ].each do |input|
      assert_equal :unknown, ShippingZone.for(input), "expected #{input.inspect} to be unknown"
    end
  end

  # Afida leadership set one off-mainland delivery policy: 2-4 working days
  # everywhere off the mainland, rather than a per-zone transit time. We quote
  # the range but PLAN to the slow end, so a parcel arriving early is a good
  # surprise and one taking the full four days still meets the promise.

  test "our off-mainland promise is never faster than DPD's own service" do
    # DPD sells Two Day on the Highlands rows and 2-4 Days on HS/ZE/KW15-17. We
    # quote 2-4 days everywhere off-mainland, which the carrier beats on the
    # Two Day rows rather than misses. A zone promised faster than DPD sells it
    # would be a commitment we cannot keep at any price, which is the failure
    # the Stornoway order (sold next-day on a 2-4 day route) already showed.
    slowest_dpd_days = 4

    (ShippingZone::ZONES - [ :mainland ]).each do |zone|
      promised_day = ShippingZone.transit_days(zone) + 1

      assert_operator promised_day, :>=, 2, "#{zone} is promised faster than DPD's fastest off-mainland service"
      assert_operator promised_day, :<=, slowest_dpd_days, "#{zone} is promised slower than DPD's slowest service"
    end
  end

  test "mainland is the only zone shipped next working day" do
    assert_equal 0, ShippingZone.transit_days(:mainland)

    (ShippingZone::ZONES - [ :mainland ]).each do |zone|
      assert_operator ShippingZone.transit_days(zone), :>, 0,
                      "#{zone} must not be sold as next working day"
    end
  end

  test "every off-mainland zone plans to the slow end of the 2-4 day range" do
    (ShippingZone::ZONES - [ :mainland ]).each do |zone|
      assert_equal 3, ShippingZone.transit_days(zone),
                   "#{zone} should add 3 days on top of the next-day hop, landing on day 4"
    end
  end

  test "mainland zone is deliverable and priced at the standard cost" do
    assert ShippingZone.deliverable?(:mainland)
    assert_nil ShippingZone.delivery_cost(:mainland),
               "mainland has no zone price of its own; it falls through to Shipping::STANDARD_COST"
  end

  test "unknown zone is not deliverable" do
    assert_not ShippingZone.deliverable?(:unknown)
  end

  test "every non-mainland zone declares a delivery cost" do
    (ShippingZone::ZONES - [ :mainland ]).each do |zone|
      assert_not_nil ShippingZone.delivery_cost(zone), "expected #{zone} to declare a delivery cost"
    end
  end

  test "every off-mainland zone is charged the same delivery cost" do
    # Afida leadership confirmed the only granularity needed is mainland vs
    # off-mainland, so a per-zone price tier would contradict the agreed policy
    # (and would show customers different prices for the same service level).
    costs = (ShippingZone::ZONES - [ :mainland ]).map { |z| ShippingZone.delivery_cost(z) }

    assert_equal 1, costs.uniq.size,
                 "expected one off-mainland delivery cost, got #{costs.uniq.inspect}"
  end

  test "the off-mainland cost is the whole delivery charge, not an addition to it" do
    # Afida leadership quoted £25 off-mainland as the TOTAL delivery charge. An
    # earlier revision read it as a surcharge on top of the £6.99 mainland rate,
    # which billed £31.99. Pinning the total here so it cannot drift back.
    assert_equal BigDecimal("25.00"), Shipping.cost_for_zone_in_pounds(:highlands)
    assert_equal BigDecimal("25.00"), Shipping.cost_for_zone_in_pounds(:northern_ireland)
  end

  test "off-mainland delivery costs one figure, mainland another" do
    costs = (ShippingZone::ZONES - [ :mainland ]).map { |z| Shipping.cost_for_zone_in_pounds(z) }

    assert_equal 1, costs.uniq.size, "off-mainland must be a single price, not a range"
    assert_operator costs.first, :>, Shipping.cost_for_zone_in_pounds(:mainland)
  end

  # The zone lookup only needs the outward code, and "IV51" is the natural thing
  # to type into a "calculate delivery" field. Rejecting it would tell a customer
  # their real postcode wasn't recognised.

  test "an outward code alone resolves to its zone" do
    assert_equal :highlands, ShippingZone.for("IV51")
    assert_equal :northern_ireland, ShippingZone.for("BT1")
    assert_equal :mainland, ShippingZone.for("WD18")
    assert_equal :remote_islands, ShippingZone.for("HS1")
  end

  test "an outward code agrees with the full postcode it came from" do
    { "IV51" => "IV51 9YB", "BT1" => "BT1 6EE", "WD18" => "WD18 9SB" }.each do |outward, full|
      assert_equal ShippingZone.for(full), ShippingZone.for(outward),
                   "#{outward} must resolve like #{full}"
    end
  end

  test "still rejects input that is not a postcode at all" do
    [ "nonsense", "12345", "", nil, "!!" ].each do |input|
      assert_equal :unknown, ShippingZone.for(input), "expected #{input.inspect} to stay unknown"
    end
  end

  test "an env override sets the delivery cost" do
    with_env("SHIPPING_COST_HIGHLANDS", "35.00") do
      assert_equal BigDecimal("35.00"), ShippingZone.delivery_cost(:highlands)
    end
  end

  test "a malformed env override falls back to the default instead of raising" do
    # delivery_cost is reached from Cart#cart_totals on every cart and drawer
    # render, so a typo like "25GBP" would otherwise 500 the whole storefront
    # rather than degrade to a sane figure.
    with_env("SHIPPING_COST_HIGHLANDS", "25GBP") do
      assert_equal BigDecimal(ShippingZone::DEFAULT_COSTS.fetch(:highlands)),
                   ShippingZone.delivery_cost(:highlands)
    end
  end

  private

  # DPD UK's row for this (area, district), or nil when it is not on the table
  # and so takes the standard rate.
  def dpd_uk_row(area, district)
    DPD_UK_SCOTLAND.find { |row_area, districts, _| row_area == area && districts.cover?(district) }
  end

  def with_env(key, value)
    original = ENV[key]
    ENV[key] = value
    yield
  ensure
    ENV[key] = original
  end

  # The customer-facing transit label. It rides in the Stripe line-item name and
  # the cart, so a zone we cannot reach next day never reads "next working day".

  test "mainland keeps the next-working-day label" do
    assert_equal "next working day", ShippingZone.transit_label(:mainland)
  end

  test "every off-mainland zone is quoted as the 2-4 day range" do
    (ShippingZone::ZONES - [ :mainland ]).each do |zone|
      assert_equal "2-4 working days", ShippingZone.transit_label(zone)
    end
  end

  test "the quoted range covers the day the delivery date is planned to" do
    # The label is a RANGE while DeliveryEstimate stamps a single date, so the
    # two can't be asserted equal. What must hold is that the planned date falls
    # inside the quoted range: quoting 2-4 days and then promising day 5 would be
    # a contradiction the customer sees on the confirmation email.
    (ShippingZone::ZONES - [ :mainland ]).each do |zone|
      planned_day = ShippingZone.transit_days(zone) + 1

      assert_operator planned_day, :>=, 2, "#{zone} plans earlier than the quoted range"
      assert_operator planned_day, :<=, 4, "#{zone} plans later than the quoted range"
    end
  end

  test "an undeliverable zone is never labelled next working day" do
    # transit_days defaults unknown zones to 0, which would sell an address we
    # could not identify as next-day. Callers normalise to mainland first, so
    # this is a fail-safe rather than a live path.
    assert_not_equal "next working day", ShippingZone.transit_label(:unknown)
  end

  test "no zone label promises next working day unless its transit is zero" do
    ShippingZone::ZONES.each do |zone|
      next if ShippingZone.transit_days(zone).zero?

      assert_not_equal "next working day", ShippingZone.transit_label(zone),
                       "#{zone} takes #{ShippingZone.transit_days(zone)} extra days but is sold as next-day"
    end
  end

  # Free delivery is a mainland promise. Every other zone pays, which is exactly
  # the leak this class exists to close (two real orders shipped free to
  # Northern Ireland and Skye).

  test "free shipping applies to mainland only" do
    assert ShippingZone.free_shipping?(:mainland)

    (ShippingZone::ZONES - [ :mainland ]).each do |zone|
      assert_not ShippingZone.free_shipping?(zone), "expected #{zone} not to ship free"
    end
  end

  test "an unknown zone never ships free" do
    assert_not ShippingZone.free_shipping?(:unknown)
  end
end
