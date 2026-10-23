require "test_helper"

# Customers who lost the confirmation email download their VAT invoice from
# the order page, and admins resend it from the admin order page. Access
# mirrors orders#show: owner, the session that placed the order, or the
# signed token from the email link.
class OrderInvoicesTest < ActionDispatch::IntegrationTest
  setup do
    @user_one = users(:one)
    @user_two = users(:two)
    @order_one = orders(:one)            # paid, belongs to user_one
    @guest_order = orders(:guest_order)  # paid, no user
  end

  def sign_in(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end

  def assert_invoice_pdf(order)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF")
    assert_includes response.headers["Content-Disposition"], order.invoice_filename
  end

  test "the owner downloads the invoice" do
    sign_in @user_one
    get invoice_order_url(@order_one)

    assert_invoice_pdf(@order_one)
  end

  test "a guest downloads the invoice with the token from the email link" do
    get invoice_order_url(@guest_order, token: @guest_order.signed_access_token)

    assert_invoice_pdf(@guest_order)
  end

  test "a guest without a token is turned away" do
    get invoice_order_url(@guest_order)

    assert_redirected_to root_path
  end

  test "another customer is turned away" do
    sign_in @user_two
    get invoice_order_url(@order_one)

    assert_redirected_to root_path
  end

  # A refunded or unpaid order has no valid VAT invoice (a refund needs a
  # credit note), so the document is not offered.
  test "an order that is not paid has no invoice" do
    @order_one.update_columns(status: "refunded")
    sign_in @user_one
    get invoice_order_url(@order_one)

    assert_redirected_to order_path(@order_one)
    assert_equal "An invoice is only available for a paid order.", flash[:alert]
  end

  test "the order page links the owner to the invoice" do
    sign_in @user_one
    get order_url(@order_one)

    assert_select "a[href=?]", invoice_order_path(@order_one), text: /Download invoice/
  end

  test "the order page keeps the guest's token on the invoice link" do
    token = @guest_order.signed_access_token
    get order_url(@guest_order, token: token)

    assert_select "a[href=?]", invoice_order_path(@guest_order, token: token), text: /Download invoice/
  end

  test "the order page offers no invoice for an order that is not paid" do
    @order_one.update_columns(status: "refunded")
    sign_in @user_one
    get order_url(@order_one)

    assert_select "a", text: /Download invoice/, count: 0
  end
end

class AdminOrderInvoicesTest < ActionDispatch::IntegrationTest
  setup do
    @headers = { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }
    post session_url, params: { email_address: users(:acme_admin).email_address, password: "password" }, headers: @headers
    @order = orders(:one)
  end

  test "an admin downloads any paid order's invoice" do
    get invoice_admin_order_path(@order), headers: @headers

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_includes response.headers["Content-Disposition"], @order.invoice_filename
  end

  test "an admin gets no invoice for an order that is not paid" do
    @order.update_columns(status: "refunded")
    get invoice_admin_order_path(@order), headers: @headers

    assert_redirected_to admin_order_path(@order)
  end

  test "the admin order page links to the invoice" do
    get admin_order_path(@order), headers: @headers

    assert_select "a[href=?]", invoice_admin_order_path(@order), text: /Download invoice/
  end
end
