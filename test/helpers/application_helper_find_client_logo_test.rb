require "test_helper"

class ApplicationHelperFindClientLogoTest < ActionView::TestCase
  include ApplicationHelper

  test "finds hawksmoor logo by exact name" do
    assert_equal "hawksmoor.webp", find_client_logo("Hawksmoor")
  end

  test "finds la gelatiera logo by name" do
    assert_equal "la-gelateria.webp", find_client_logo("La Gelatiera")
  end

  test "finds marriott logo by name" do
    assert_equal "marriott.svg", find_client_logo("Marriott")
  end

  test "finds mandarin oriental logo" do
    assert_equal "mandarin-oriental.svg", find_client_logo("Mandarin Oriental")
  end

  test "returns nil for unknown client" do
    assert_nil find_client_logo("Unknown Client Name")
  end

  test "is case insensitive" do
    assert_equal "hawksmoor.webp", find_client_logo("hawksmoor")
  end
end
