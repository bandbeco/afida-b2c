# frozen_string_literal: true

require "test_helper"

class AgentOauthTest < ActionDispatch::IntegrationTest
  test "dynamic client registration issues credentials" do
    post "/oauth/register", params: { client_name: "Cafe Bot" }, as: :json

    assert_response :created
    body = response.parsed_body
    assert body["client_id"].present?
    assert body["client_secret"].present?
  end

  test "client_credentials grant returns a bearer token" do
    post "/oauth/register", params: { client_name: "Cafe Bot" }, as: :json
    client_id = response.parsed_body["client_id"]
    client_secret = response.parsed_body["client_secret"]

    post "/oauth/token", params: {
      grant_type: "client_credentials",
      client_id: client_id,
      client_secret: client_secret
    }, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["access_token"].present?
    assert_equal "Bearer", body["token_type"]
  end

  test "jwks publishes an RSA public key" do
    get "/oauth/jwks"

    assert_response :success
    keys = response.parsed_body["keys"]
    assert keys.is_a?(Array)
    assert_equal "RSA", keys.first["kty"]
    assert keys.first["n"].present?
    assert keys.first["e"].present?
  end

  test "invalid client credentials are rejected" do
    post "/oauth/token", params: {
      grant_type: "client_credentials",
      client_id: "unknown",
      client_secret: "nope"
    }, as: :json

    assert_response :unauthorized
  end
end
