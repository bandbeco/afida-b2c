require "test_helper"

# Regression guard against the real order book. These are the actual shipping
# postcodes from all 106 production orders as at 2026-07-24, which is the data
# that exposed the bug: 5 of them are non-mainland and 2 were given free
# delivery under the unqualified "over £100" promise.
#
# The point of pinning real postcodes is the near-misses they contain: KA1
# (Kilmarnock), PH2 (Perth), TR8 and TR26 (Cornwall) all sit in the same
# postcode areas as surcharged ranges. A regression to area-letter matching
# would start surcharging real customers, and this test would catch it.
class ShippingZoneProductionDataTest < ActiveSupport::TestCase
  NON_MAINLAND = {
    "IV51 9YB" => :highlands,
    "BT25 1JX" => :northern_ireland,
    "Bt618he"  => :northern_ireland,
    "HS1 2DD"  => :remote_islands,
    "BT1 6EE"  => :northern_ireland
  }.freeze

  MAINLAND = %w[
    CT91RW W8\ 5NP SE8\ 5JN W4\ 1PU LL22\ 9LB L36\ 9TD SO43\ 7FZ NW1\ 0ND
    SP1\ 3FL LS10\ 1GE M20\ 1QB SW38YU SE5\ 8SY SW6\ 1AA LL61\ 6NX SO31\ 4HQ
    SA1\ 8RG WD19\ 4NN E58NF TW7\ 4BX MK17\ 0SH W8\ 4PE NW4\ 4DP E5\ 9EW
    CF82\ 7DU OX13\ 6RP KA1\ 1UR BS5\ 8AH E10\ 7QP CA7\ 9PA FY8\ 1LS
    NG23\ 5NS N1\ 3DS NR2\ 4UX OL7\ 0TL CH3\ 9PX NR2\ 3NL LA8\ 9NU GL7\ 6JA
    TN22\ 4BF G20\ 6AG LE67\ 9RJ PE275DJ LN11\ 8EL OX1\ 4BG CT21\ 4HA
    TN12\ 9AW WR97TB NW7\ 2HE CW6\ 0HX RM10\ 7YA DT9\ 3AP NW3\ 2JE BN2\ 1AU
    HA0\ 1TW TR8\ 4AB TN129QJ TQ9\ 5JT N10\ 1AA CT20\ 3TD L3\ 2AT PH2\ 6FB
    RH17\ 6PH Bh193eb CF35\ 6ST B29\ 6AE GU152PA TQ6\ 9EN BN1\ 4JU E14\ 5AA
    HA0\ 1HX EN7\ 6LA CT9\ 1EN E8\ 2NG SE18\ 1QJ TN38\ 0PA TR26\ 3HA
    B13\ 8LE M336SB MK5\ 6AJ YO17\ 8NP NW27TS
  ].freeze

  test "the five known non-mainland orders resolve to their zones" do
    NON_MAINLAND.each do |postcode, zone|
      assert_equal zone, ShippingZone.for(postcode), "expected #{postcode} to be #{zone}"
    end
  end

  test "every other production postcode is mainland" do
    MAINLAND.each do |postcode|
      assert_equal :mainland, ShippingZone.for(postcode),
                   "expected #{postcode} to be mainland - a false surcharge would hit a real customer"
    end
  end

  test "no production postcode fails to parse" do
    (MAINLAND + NON_MAINLAND.keys).each do |postcode|
      assert_not_equal :unknown, ShippingZone.for(postcode),
                       "#{postcode} is a real delivered-to postcode and must parse"
    end
  end

  test "only the known non-mainland orders carry a surcharge" do
    surcharged = (MAINLAND + NON_MAINLAND.keys).reject do |postcode|
      ShippingZone.surcharge(ShippingZone.for(postcode)).zero?
    end

    assert_equal NON_MAINLAND.keys.sort, surcharged.sort
  end
end
