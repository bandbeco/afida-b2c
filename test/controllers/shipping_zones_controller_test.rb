require "test_helper"

class ShippingZonesControllerTest < ActionDispatch::IntegrationTest
  test "resolves a mainland postcode" do
    get shipping_zone_path, params: { postcode: "WD18 9SB" }

    assert_response :success
    assert_equal({ "zone" => "mainland", "deliverable" => true }, response.parsed_body)
  end

  test "resolves a highlands postcode" do
    get shipping_zone_path, params: { postcode: "IV51 9XX" }

    assert_equal "highlands", response.parsed_body["zone"]
  end

  test "resolves an outward code alone, as the cart field does" do
    get shipping_zone_path, params: { postcode: "BT1" }

    assert_equal({ "zone" => "northern_ireland", "deliverable" => true }, response.parsed_body)
  end

  test "unparseable postcode is unknown and not deliverable" do
    get shipping_zone_path, params: { postcode: "banana" }

    assert_equal({ "zone" => "unknown", "deliverable" => false }, response.parsed_body)
  end

  test "works logged out" do
    get shipping_zone_path, params: { postcode: "SW1A 1AA" }

    assert_response :success
  end
end
