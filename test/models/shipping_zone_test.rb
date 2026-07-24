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

  test "mainland is the only zone shipped next working day" do
    assert_equal 0, ShippingZone.transit_days(:mainland)
    assert_operator ShippingZone.transit_days(:highlands), :>, 0
    assert_operator ShippingZone.transit_days(:northern_ireland), :>, 0
    assert_operator ShippingZone.transit_days(:remote_islands), :>,
                    ShippingZone.transit_days(:highlands)
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
end
