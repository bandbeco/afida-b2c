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
      "AB31 4AA" => "Aberdeenshire",
      "AB37 9AA" => "Northern Highlands",
      "AB45 1AA" => "Banff",
      "AB55 4AA" => "Keith",
      "FK17 8AA" => "Argyll",
      "IV1 1AA" => "Inverness",
      "IV51 9YB" => "Skye",
      "IV63 7AA" => "Loch Ness",
      "KA27 8AA" => "Arran",
      "KA28 0AA" => "Cumbrae",
      "KW1 4AA" => "Wick",
      "KW14 7AA" => "Thurso",
      "PA20 0AA" => "Bute",
      "PA78 6AA" => "Tiree",
      "PH19 1AA" => "Dalwhinnie",
      "PH33 6AA" => "Fort William",
      "PH41 4AA" => "Mallaig",
      "PH50 4AA" => "Kinlochleven"
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

  # The near-miss cases: same postcode area as a surcharged range but a district
  # number outside it. Matching on area letters alone would wrongly surcharge
  # these, and KA1, PH2, TR8 and TR26 all appear in real production orders.
  test "mainland districts sharing an area with a surcharged range stay mainland" do
    {
      "AB10 1AA" => "Aberdeen city vs AB31-56",
      "AB25 1AA" => "Aberdeen city vs AB31-56",
      "FK1 1AA" => "Falkirk vs FK17-21",
      "KA1 1UR" => "Kilmarnock vs KA27-28",
      "KW18 1AA" => "above the KW range",
      "PA1 1AA" => "Paisley vs PA20-78",
      "PH1 1AA" => "Perth vs PH19-50",
      "PH2 6FB" => "Perth vs PH19-50",
      "PH15 2AA" => "Dundee-serviced band, not Highlands",
      "PH18 5AA" => "Dundee-serviced band, not Highlands",
      "PO1 1AA" => "Portsmouth vs PO30-41",
      "PO50 1AA" => "above the Isle of Wight range",
      "TR8 4AB" => "Cornwall mainland vs TR21-25",
      "TR26 3HA" => "St Ives vs TR21-25"
    }.each do |postcode, why|
      assert_equal :mainland, ShippingZone.for(postcode), "expected #{postcode} to be mainland (#{why})"
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

  test "mainland zone is deliverable and carries no surcharge" do
    assert ShippingZone.deliverable?(:mainland)
    assert_equal 0, ShippingZone.surcharge(:mainland)
  end

  test "unknown zone is not deliverable" do
    assert_not ShippingZone.deliverable?(:unknown)
  end

  test "every non-mainland zone declares a surcharge" do
    (ShippingZone::ZONES - [ :mainland ]).each do |zone|
      assert_not_nil ShippingZone.surcharge(zone), "expected #{zone} to declare a surcharge"
    end
  end

  test "every off-mainland zone is charged the same surcharge" do
    # Afida leadership confirmed the only granularity needed is mainland vs
    # off-mainland, so a per-zone price tier would contradict the agreed policy
    # (and would show customers different prices for the same service level).
    surcharges = (ShippingZone::ZONES - [ :mainland ]).map { |z| ShippingZone.surcharge(z) }

    assert_equal 1, surcharges.uniq.size,
                 "expected one off-mainland surcharge, got #{surcharges.uniq.inspect}"
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

  test "an env override sets the surcharge" do
    with_env("SHIPPING_SURCHARGE_HIGHLANDS", "15.00") do
      assert_equal BigDecimal("15.00"), ShippingZone.surcharge(:highlands)
    end
  end

  test "a malformed env override falls back to the default instead of raising" do
    # surcharge is reached from Cart#cart_totals on every cart and drawer render,
    # so a typo like "12.50GBP" would otherwise 500 the whole storefront rather
    # than degrade to a sane figure.
    with_env("SHIPPING_SURCHARGE_HIGHLANDS", "12.50GBP") do
      assert_equal BigDecimal(ShippingZone::DEFAULT_SURCHARGES.fetch(:highlands)),
                   ShippingZone.surcharge(:highlands)
    end
  end

  private

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
