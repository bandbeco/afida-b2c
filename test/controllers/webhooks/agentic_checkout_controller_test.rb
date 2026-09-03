require "test_helper"

class Webhooks::AgenticCheckoutControllerTest < ActionDispatch::IntegrationTest
  include StripeTestHelper

  HOOK_SECRET = "whsec_agentic_test_secret"

  setup do
    Rails.application.credentials.stubs(:dig).with(:stripe, :agentic_hook_secret).returns(HOOK_SECRET)
    Rails.application.credentials.stubs(:dig).with(:stripe, :publishable_key).returns("pk_test")
    Rails.application.credentials.stubs(:dig).with(:stripe, :secret_key).returns("sk_test")
  end

  test "rejects a request whose signature does not verify" do
    payload = customize_checkout_payload.to_json

    post webhooks_stripe_agentic_checkout_url, params: payload,
      headers: { "CONTENT_TYPE" => "application/json", "HTTP_STRIPE_SIGNATURE" => "t=1,v1=bad" }

    assert_response :bad_request
  end

  test "quotes standard delivery and applies UK VAT to every line item for a mainland address" do
    tax_rate = stub_stripe_tax_rate_list
    payload = customize_checkout_payload(postal_code: "SW1A 1AA", amount_subtotal: 2600).to_json

    post webhooks_stripe_agentic_checkout_url, params: payload, headers: signed_headers(payload)

    assert_response :ok
    body = response.parsed_body
    assert_equal 1, body["shipping_options"].size
    option = body["shipping_options"].first["shipping_rate_data"]
    assert_equal 699, option["fixed_amount"]["amount"]
    assert_equal "gbp", option["fixed_amount"]["currency"]
    assert_equal "exclusive", option["tax_behavior"]
    assert_equal "Standard delivery (next working day)", option["display_name"]
    assert_equal [ { "id" => "li_1", "tax_rates" => [ { "rate" => tax_rate.id } ] } ], body["line_items"]
  end

  test "quotes free delivery once the mainland subtotal reaches the free-shipping threshold" do
    stub_stripe_tax_rate_list
    payload = customize_checkout_payload(postal_code: "SW1A 1AA", amount_subtotal: 10_000).to_json

    post webhooks_stripe_agentic_checkout_url, params: payload, headers: signed_headers(payload)

    option = response.parsed_body["shipping_options"].first["shipping_rate_data"]
    assert_equal 0, option["fixed_amount"]["amount"]
    assert_equal "Free delivery (next working day)", option["display_name"]
  end

  test "quotes the off-mainland charge for a Highlands postcode even over the threshold" do
    stub_stripe_tax_rate_list
    payload = customize_checkout_payload(postal_code: "IV2 3AB", amount_subtotal: 10_000).to_json

    post webhooks_stripe_agentic_checkout_url, params: payload, headers: signed_headers(payload)

    option = response.parsed_body["shipping_options"].first["shipping_rate_data"]
    assert_equal 2500, option["fixed_amount"]["amount"]
    assert_equal "Standard delivery (2-4 working days)", option["display_name"]
    assert_equal({ "unit" => "business_day", "value" => 2 }, option["delivery_estimate"]["minimum"])
    assert_equal({ "unit" => "business_day", "value" => 4 }, option["delivery_estimate"]["maximum"])
  end

  test "offers no shipping option to an address outside the UK" do
    stub_stripe_tax_rate_list
    payload = customize_checkout_payload(postal_code: "75001", country: "FR").to_json

    post webhooks_stripe_agentic_checkout_url, params: payload, headers: signed_headers(payload)

    assert_response :ok
    assert_equal [], response.parsed_body["shipping_options"]
  end

  test "offers no shipping option to the Channel Islands" do
    stub_stripe_tax_rate_list
    payload = customize_checkout_payload(postal_code: "JE2 3AB").to_json

    post webhooks_stripe_agentic_checkout_url, params: payload, headers: signed_headers(payload)

    assert_equal [], response.parsed_body["shipping_options"]
  end

  test "applies the VAT rate to each of several line items" do
    tax_rate = stub_stripe_tax_rate_list
    items = [
      { id: "li_1", sku_id: "A", unit_amount: 1000, quantity: 1, amount_subtotal: 1000, tax_rates: [] },
      { id: "li_2", sku_id: "B", unit_amount: 500, quantity: 2, amount_subtotal: 1000, tax_rates: [] }
    ]
    payload = customize_checkout_payload(line_items: items).to_json

    post webhooks_stripe_agentic_checkout_url, params: payload, headers: signed_headers(payload)

    assert_equal %w[li_1 li_2], response.parsed_body["line_items"].map { |item| item["id"] }
    assert response.parsed_body["line_items"].all? { |item| item["tax_rates"] == [ { "rate" => tax_rate.id } ] }
  end

  test "sends no manual tax rates when Stripe Tax is calculating the checkout" do
    Stripe::TaxRate.expects(:list).never
    payload = customize_checkout_payload
    payload[:data][:automatic_tax][:enabled] = true

    post webhooks_stripe_agentic_checkout_url, params: payload.to_json, headers: signed_headers(payload.to_json)

    assert_equal [], response.parsed_body["line_items"]
    assert_equal 1, response.parsed_body["shipping_options"].size
  end

  test "rejects a request signed with a different secret" do
    payload = customize_checkout_payload.to_json

    post webhooks_stripe_agentic_checkout_url, params: payload, headers: signed_headers(payload, secret: "whsec_other")

    assert_response :bad_request
  end

  test "answers with no customization while no hook secret is configured" do
    # Stripe checks the endpoint when the hook is saved, and the signing secret
    # only exists after that save. Until the secret is in credentials the
    # endpoint therefore returns an empty customization (Stripe falls back to
    # the catalogue's shipping and tax) rather than a 400 that blocks the save.
    Rails.application.credentials.stubs(:dig).with(:stripe, :agentic_hook_secret).returns(nil)
    Stripe::TaxRate.expects(:list).never
    payload = customize_checkout_payload.to_json

    post webhooks_stripe_agentic_checkout_url, params: payload, headers: signed_headers(payload)

    assert_response :ok
    assert_equal({}, response.parsed_body)
  end

  private

  def customize_checkout_payload(postal_code: "SW1A 1AA", country: "GB", amount_subtotal: 2600, line_items: nil)
    line_items ||= [
      { id: "li_1", sku_id: "CUP-SW-8-WHT", unit_amount: 2600, quantity: 1,
        amount_subtotal: 2600, amount_discount: 0, amount_tax: 0, amount_total: 2600,
        name: "8oz White", tax_rates: [] }
    ]
    {
      type: "v1.delegated_checkout.customize_checkout",
      id: "dchk_test_1",
      livemode: false,
      data: {
        automatic_tax: { enabled: false },
        currency: "gbp",
        amount_subtotal: amount_subtotal,
        line_item_details: line_items,
        shipping_details: {
          address: { line1: "1 Test Street", city: "London", postal_code: postal_code, country: country }
        }
      }
    }
  end

  def signed_headers(payload, secret: HOOK_SECRET)
    timestamp = Time.now
    signature = Stripe::Webhook::Signature.compute_signature(timestamp, payload, secret)
    header = Stripe::Webhook::Signature.generate_header(timestamp, signature)
    { "CONTENT_TYPE" => "application/json", "HTTP_STRIPE_SIGNATURE" => header }
  end
end
