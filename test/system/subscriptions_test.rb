# frozen_string_literal: true

require "application_system_test_case"

class SubscriptionsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @active_subscription = subscriptions(:active_monthly)
    @paused_subscription = subscriptions(:paused_subscription)
  end

  test "user can view their subscriptions" do
    sign_in @user

    visit subscriptions_path

    assert_text "Your Subscriptions"
    assert_text "Every month Delivery"
    assert_text "Paused"
  end

  test "subscriptions link appears in account dropdown" do
    sign_in @user
    open_account_menu

    assert_selector "[data-testid='account-dropdown'] a", text: "Subscriptions", visible: :all
  end

  test "clicking subscriptions link navigates to subscriptions page" do
    sign_in @user
    open_account_menu

    find("[data-testid='account-dropdown'] a", text: "Subscriptions", visible: :all).click

    assert_current_path subscriptions_path
    assert_text "Your Subscriptions"
  end

  test "active subscription shows pause and cancel buttons" do
    sign_in @user

    visit subscriptions_path

    # Find the active subscription card by status badge
    within("article", text: /Active\s*$/) do
      assert_button "Pause"
      assert_button "Cancel"
    end
  end

  test "paused subscription shows resume and cancel buttons" do
    sign_in @user

    visit subscriptions_path

    # Find the paused subscription card by "Paused" status badge
    within("article", match: :first, text: /Paused\s*$/) do
      assert_button "Resume"
      assert_button "Cancel"
    end
  end

  test "user can pause an active subscription" do
    sign_in @user

    visit subscriptions_path

    # Accept the confirmation dialog - find active subscription by status
    accept_confirm do
      within("article", text: /Active\s*$/) do
        click_button "Pause"
      end
    end

    assert_text "Your subscription has been paused"
  end

  test "user can resume a paused subscription" do
    sign_in @user

    visit subscriptions_path

    accept_confirm do
      within("article", match: :first, text: /Paused\s*$/) do
        click_button "Resume"
      end
    end

    assert_text "Your subscription has been resumed"
  end

  private

  def sign_in(user)
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign In"
    assert_selector ".avatar-placeholder", wait: 5
  end

  def open_account_menu
    find("[data-testid='account-dropdown'] summary").click
    assert_selector "[data-testid='account-dropdown'][open]", wait: 3
  end
end
