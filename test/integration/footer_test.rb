# frozen_string_literal: true

require "test_helper"

class FooterTest < ActionDispatch::IntegrationTest
  test "social links use target _blank" do
    get root_url
    assert_response :success
    assert_select "footer a[href='https://www.linkedin.com/company/afidasupplies'][target='_blank']"
    assert_select "footer a[href='https://www.instagram.com/afidasupplies'][target='_blank']"
  end

  test "social links have aria-labels" do
    get root_url
    assert_response :success
    assert_select "footer a[aria-label='LinkedIn']"
    assert_select "footer a[aria-label='Instagram']"
  end

  test "footer displays physical address" do
    get root_url
    assert_response :success
    assert_select "footer address", text: /Unit 27, The Metro Centre/
    assert_select "footer address", text: /WD18 9SB/
  end

  test "footer displays phone number" do
    get root_url
    assert_response :success
    assert_select "footer a[href='tel:+442033027719']", text: "0203 302 7719"
  end

  test "footer displays email" do
    get root_url
    assert_response :success
    assert_select "footer a[href='mailto:hello@afida.com']", text: "hello@afida.com"
  end
end
