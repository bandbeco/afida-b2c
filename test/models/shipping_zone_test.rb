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
      "PA20 0AA" => "Bute",
      "PA38 4AA" => "Appin",
      "PA41 7AA" => "Gigha",
      "PA49 7AA" => "Islay",
      "PA60 7AA" => "Jura",
      "PA78 6AA" => "Tiree",
      "PA80 5AA" => "top of the Argyll islands range",
      "PH16 5AA" => "Pitlochry",
      "PH18 5AA" => "Blair Atholl",
      "PH19 1AA" => "Dalwhinnie",
      "PH33 6AA" => "Fort William",
      "PH41 4AA" => "Mallaig",
      "PH50 4AA" => "Kinlochleven"
    }.each do |postcode, place|
      assert_equal :highlands, ShippingZone.for(postcode), "expected #{postcode} (#{place}) to be highlands"
    end
  end

  # DPD's list carries THREE gaps inside the Argyll/Bute range (PA20-38, PA41-49,
  # PA60-80), not one continuous band. PA39-40 and PA50-59 are unlisted, so they
  # take the standard rate; treating PA20-80 as one block surcharged them wrongly.
  test "the unlisted gaps inside the argyll range stay mainland" do
    {
      "PA39 4AA" => "between the PA20-38 and PA41-49 bands",
      "PA40 4AA" => "between the PA20-38 and PA41-49 bands",
      "PA50 6AA" => "between the PA41-49 and PA60-80 bands",
      "PA59 6AA" => "between the PA41-49 and PA60-80 bands"
    }.each do |postcode, why|
      assert_equal :mainland, ShippingZone.for(postcode), "expected #{postcode} to be mainland (#{why})"
    end
  end

  # Aberdeenshire is NOT on DPD's list at any district. An earlier revision
  # surcharged AB31-38 and AB41-56, which would have charged the off-mainland
  # rate to ordinary Aberdeenshire addresses that DPD delivers at standard rate.
  test "aberdeenshire is mainland at every district" do
    {
      "AB10 1AA" => "Aberdeen city",
      "AB31 4AA" => "Banchory",
      "AB37 9AA" => "Tomintoul",
      "AB45 1AA" => "Banff",
      "AB55 4AA" => "Keith",
      "AB56 1AA" => "top of the area"
    }.each do |postcode, place|
      assert_equal :mainland, ShippingZone.for(postcode), "expected #{postcode} (#{place}) to be mainland"
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
      "AB10 1AA" => "Aberdeen city, and AB is unlisted entirely",
      "AB25 1AA" => "Aberdeen city, and AB is unlisted entirely",
      "FK1 1AA" => "Falkirk vs FK17-21",
      "KA1 1UR" => "Kilmarnock vs KA27-28",
      "PA1 1AA" => "Paisley vs PA20-38",
      "PH1 1AA" => "Perth vs PH16-50",
      "PH2 6FB" => "Perth vs PH16-50",
      "PH15 2AA" => "Aberfeldy, just below the PH16 boundary",
      "PO1 1AA" => "Portsmouth vs PO30-41",
      "PO50 1AA" => "above the Isle of Wight range",
      "TR8 4AB" => "Cornwall mainland vs TR21-25",
      "TR26 3HA" => "St Ives vs TR21-25"
    }.each do |postcode, why|
      assert_equal :mainland, ShippingZone.for(postcode), "expected #{postcode} to be mainland (#{why})"
    end
  end

  # The whole GB row of DPD's "Islands and regions subject to surcharge" list
  # (DPD CLASSIC & DPD EXPRESS, 06/2020), transcribed here as the source of
  # truth. Pinning the entire row rather than sampled postcodes means a future
  # edit to the zone table is checked against the carrier's document, not
  # against whichever examples happened to be in the other tests.
  #
  # GY, JE and IM are on the list but excluded: they are not GB, so
  # Shipping::ALLOWED_COUNTRIES refuses them before this lookup is reached.
  DPD_SURCHARGED_GB = {
    "BT" => :all,
    "HS" => :all,
    "IV" => :all,
    "KW" => :all,
    "ZE" => :all,
    "KA" => [ 27..28 ],
    "FK" => [ 17..21 ],
    "PA" => [ 20..38, 41..49, 60..80 ],
    "PH" => [ 16..50 ],
    "PO" => [ 30..41 ],
    "TR" => [ 21..25 ]
  }.freeze

  # Highest allocated district per area (Royal Mail), so the sweep below asks
  # only about postcodes that can exist.
  ALLOCATED_DISTRICTS = {
    "AB" => 56, "BT" => 94, "FK" => 21, "HS" => 9, "IV" => 63, "KA" => 30,
    "KW" => 17, "PA" => 80, "PH" => 50, "PO" => 41, "TR" => 27, "ZE" => 3
  }.freeze

  test "every allocated district matches DPD's published list" do
    mismatches = ALLOCATED_DISTRICTS.flat_map do |area, highest|
      (1..highest).filter_map do |district|
        listed = dpd_surcharged?(area, district)
        ours = ShippingZone.for("#{area}#{district}") != :mainland

        next if listed == ours

        "#{area}#{district}: DPD says #{listed ? "surcharged" : "standard"}, we say #{ShippingZone.for("#{area}#{district}")}"
      end
    end

    assert_empty mismatches, "zone table disagrees with DPD:\n  #{mismatches.join("\n  ")}"
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

  # Whether DPD's list surcharges this (area, district), per DPD_SURCHARGED_GB.
  def dpd_surcharged?(area, district)
    spec = DPD_SURCHARGED_GB[area]
    return false unless spec
    return true if spec == :all

    spec.any? { |range| range.cover?(district) }
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
