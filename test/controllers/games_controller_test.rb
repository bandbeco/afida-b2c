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

  test "the social card states the live prizes" do
    get game_path

    og_title = css_select("meta[property='og:title']").first["content"]
    og_description = css_select("meta[property='og:description']").first["content"]
    twitter_title = css_select("meta[name='twitter:title']").first["content"]
    twitter_description = css_select("meta[name='twitter:description']").first["content"]
    meta_description = css_select("meta[name='description']").first["content"]

    [ og_title, twitter_title ].each do |title|
      assert_match(/The Afida Stack/, title)
      assert_match(/15/, title)
      assert_match(/£10/, title)
    end

    [ og_description, twitter_description, meta_description ].each do |description|
      assert_match(/£10 off/, description)
      assert_match(/£100\+/, description)
      assert_match(/15/, description)
      refute_match(/beat my tower/, description)
      refute_match(/5%/, description)
    end

    assert_match(/shoutout/, og_description)
    assert_match(/@afidasupplies/, og_description)
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
    assert_equal Game::PromoCodes::BASE_WIN, boot["win_score"]
    assert_equal Game::PromoCodes::INVITED_WIN, boot["invited_win_score"]
    assert_equal "Roastery", boot["entries"].first["name"]
    assert_equal "cafe", boot["entries"].first["instagram_handle"]
  end

  test "a later board listing does not replace the page's play token" do
    js = Rails.root.join("app/frontend/entrypoints/game.js").read

    assert_match(/if \(d\.token && !lb\.token\)/, js)
  end

  test "in-play physics stay on the round's canvas width" do
    js = Rails.root.join("app/frontend/entrypoints/game.js").read

    assert_match(/function fieldW\(\)/, js)
    assert_match(/fieldW\(\) \/ 2/, js)
  end

  test "client win thresholds come from the page boot payload" do
    js = Rails.root.join("app/frontend/entrypoints/game.js").read

    assert_match(/boot\.win_score/, js)
    assert_match(/boot\.invited_win_score/, js)
    assert_no_match(/const BASE_WIN = 15/, js)
    assert_no_match(/const INVITED_WIN = 12/, js)
  end
end
