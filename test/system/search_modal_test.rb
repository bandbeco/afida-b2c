require "application_system_test_case"

# System tests for the search modal's client-side behaviour (issues #249, #250,
# #251). These exercise the Stimulus controller through a real browser since the
# keyboard, localStorage, and shortcut behaviour cannot be asserted server-side.
class SearchModalTest < ApplicationSystemTestCase
  def open_modal
    visit "/"
    find("button[aria-label='Search products']").click
    assert_selector "[data-search-modal-target='input']", visible: true
  end

  # Issue #249: Enter submits to the full results page.
  test "pressing Enter navigates to the full results page" do
    open_modal

    input = find("[data-search-modal-target='input']")
    input.fill_in with: "cup"
    input.send_keys(:enter)

    assert_current_path(/\/shop\?q=cup/)
  end

  test "pressing Enter with a too-short query does not navigate" do
    open_modal

    input = find("[data-search-modal-target='input']")
    input.fill_in with: "c"
    input.send_keys(:enter)

    assert_current_path("/")
  end
end
