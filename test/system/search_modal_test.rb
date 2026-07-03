require "application_system_test_case"

# System tests for the search modal's client-side behaviour (issues #249, #250,
# #251). These exercise the Stimulus controller through a real browser since the
# keyboard, localStorage, and shortcut behaviour cannot be asserted server-side.
class SearchModalTest < ApplicationSystemTestCase
  def open_modal
    visit "/"
    # Start each test from a clean recent-searches history.
    execute_script("window.localStorage.clear()")
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

  # Issue #250: Cmd/Ctrl+K opens the modal from anywhere.
  test "Ctrl+K opens the search modal" do
    visit "/"
    assert_selector "[data-search-modal-target='modal'].hidden", visible: :all

    find("body").send_keys([ :control, "k" ])

    assert_selector "[data-search-modal-target='input']", visible: true
  end

  # Issue #250: arrow keys move a selection through the result rows and set the
  # combobox's aria-activedescendant.
  test "arrow down selects the first result row" do
    open_modal

    input = find("[data-search-modal-target='input']")
    input.fill_in with: "cup"
    assert_selector "[role='option']", minimum: 1

    input.send_keys(:down)

    first_option_id = all("[role='option']").first[:id]
    assert_equal first_option_id, input[:"aria-activedescendant"]
    assert_equal "true", find("##{first_option_id}")[:"aria-selected"]
  end

  # Issue #251: a searched query is remembered and offered on reopen.
  test "a searched query is stored and shown as a recent search" do
    open_modal

    input = find("[data-search-modal-target='input']")
    input.fill_in with: "cup"
    assert_selector "[role='option']", minimum: 1

    # Close and reopen; the recent-searches block hydrates from localStorage.
    find("button[aria-label='Close search']").click
    find("button[aria-label='Search products']").click

    assert_selector "[data-search-modal-target='recentSearches']", visible: true
    within "[data-search-modal-target='recentSearchesList']" do
      assert_selector "button[data-term='cup']", text: "cup"
    end
  end

  # A query that returns nothing must not be stored as a recent search.
  test "a zero-result query is not stored as a recent search" do
    open_modal

    input = find("[data-search-modal-target='input']")
    input.fill_in with: "zzzznomatchquery"
    # Wait for the no-results frame to render before closing.
    assert_text(/No results found/i)

    find("button[aria-label='Close search']").click
    find("button[aria-label='Search products']").click

    # No history at all, so the recent-searches block stays hidden.
    assert_no_selector "[data-search-modal-target='recentSearches']", visible: true
  end

  # A curated "Most searched" chip click must not echo back into recent searches.
  test "clicking a Most searched chip does not record it as a recent search" do
    open_modal

    find("button[data-term='Cups']").click
    assert_selector "[role='option']", minimum: 1

    find("button[aria-label='Close search']").click
    find("button[aria-label='Search products']").click

    # "Cups" came from a curated chip, so it must not appear under Recent searches.
    assert_no_selector "[data-search-modal-target='recentSearchesList'] button[data-term='Cups']"
  end

  # The whole result row navigates to its product, delegating a background
  # click to the row's primary heading link.
  test "clicking the row background opens the representative product" do
    open_modal

    input = find("[data-search-modal-target='input']")
    input.fill_in with: "cup"
    assert_selector "[role='option']", minimum: 1

    option = all("[role='option']").first
    href = option.find("[data-search-primary-link]")[:href]
    # Click the option's own box (not an inner link) to trigger navigateRow.
    option.click

    assert_current_path(URI(href).path)
  end
end
