require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    # The test env turns forgery protection off; this page's whole point is
    # that it is a real Rails action with a CSRF token, so turn it back on.
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = false
  end

  test "the game is a Rails page with a CSRF token and no storefront cart" do
    assert_no_difference "Cart.count" do
      get game_path
    end

    assert_response :success
    assert_select "title", text: /The Afida Stack/
    assert_select "meta[name=csrf-token]"
    assert_select ".cabinet"
    assert_select "canvas#game"
    assert_select "#winEmail[placeholder='you@yourplace.com']"
    assert_select "#winEmail[placeholder*='cafe']", count: 0
  end

  test "share copy talks about businesses, not cafés" do
    js = Rails.root.join("app/frontend/entrypoints/game.js").read

    assert_match "each business that orders", js
    assert_no_match(/caf[eé]/i, js)
  end

  test "the monthly crown is a shoutout, not a case of cups" do
    get game_path

    assert_response :success
    assert_select ".fineprint", text: /case of cups/, count: 0
    assert_select ".fineprint a[href='https://www.instagram.com/afidasupplies'][target=_blank][rel=noopener]",
                  text: "@afidasupplies", count: 2
    assert_select ".fineprint", text: /Top stacker this month wins a shoutout from/, count: 2
  end

  test "the trailing-slash URL that mail and the social card already use still works" do
    get "/game/"

    assert_response :success
    assert_select "canvas#game"
  end

  test "the page boots the monthly board so play does not wait on a second fetch" do
    LeaderboardEntry.delete_all
    LeaderboardEntry.create!(name: "Roastery", score: 20, status: "approved", instagram_handle: "cafe")

    get game_path

    assert_response :success
    boot = JSON.parse(css_select("#game-board").text)
    assert boot["token"].present?
    assert_equal "Roastery", boot["entries"].first["name"]
    assert_equal "cafe", boot["entries"].first["instagram_handle"]
  end
end
