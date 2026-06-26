require "test_helper"

class OrderMailerTest < ActionMailer::TestCase
  include Rails.application.routes.url_helpers

  setup do
    @order = orders(:one)
  end

  test "confirmation_email sends email to order email address" do
    email = OrderMailer.with(order: @order).confirmation_email

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ @order.email ], email.to
  end

  test "confirmation_email has correct subject with order number" do
    email = OrderMailer.with(order: @order).confirmation_email

    assert_equal "Your Order ##{@order.order_number} is Confirmed!", email.subject
  end

  test "confirmation_email body includes order number" do
    email = OrderMailer.with(order: @order).confirmation_email

    assert_match @order.order_number, email.body.encoded
  end

  test "confirmation_email body includes shipping name" do
    email = OrderMailer.with(order: @order).confirmation_email

    assert_match @order.shipping_name, email.body.encoded
  end

  test "confirmation_email does not promise a shipping-notification email" do
    email = OrderMailer.with(order: @order).confirmation_email
    body = email.body.encoded

    assert_no_match(/another email when it ships/i, body)
    assert_no_match(/notify you when your order ships/i, body)
    assert_no_match(/notify you again when your order has shipped/i, body)
  end

  test "confirmation_email has both HTML and text parts" do
    email = OrderMailer.with(order: @order).confirmation_email

    # With PDF attachment, email becomes multipart/mixed with 2 parts:
    # 1. multipart/alternative (HTML + text)
    # 2. application/pdf (attachment)
    assert_equal 2, email.parts.size
    assert_equal "multipart/mixed", email.mime_type

    # Find the multipart/alternative part (contains HTML and text)
    content_part = email.parts.find { |p| p.content_type.include?("multipart/alternative") }
    assert_not_nil content_part, "Should have multipart/alternative content part"

    # Check for HTML part within the alternative part
    html_part = content_part.parts.find { |p| p.content_type.include?("text/html") }
    assert_not_nil html_part

    # Check for text part within the alternative part
    text_part = content_part.parts.find { |p| p.content_type.include?("text/plain") }
    assert_not_nil text_part
  end

  test "confirmation_email HTML body includes order details" do
    email = OrderMailer.with(order: @order).confirmation_email

    # Find the multipart/alternative part, then get HTML from it
    content_part = email.parts.find { |p| p.content_type.include?("multipart/alternative") }
    html_part = content_part.parts.find { |p| p.content_type.include?("text/html") }

    assert_match @order.order_number, html_part.body.to_s
    assert_match @order.shipping_name, html_part.body.to_s
  end

  test "confirmation_email text body includes order number" do
    email = OrderMailer.with(order: @order).confirmation_email

    # Find the multipart/alternative part, then get text from it
    content_part = email.parts.find { |p| p.content_type.include?("multipart/alternative") }
    text_part = content_part.parts.find { |p| p.content_type.include?("text/plain") }

    assert_match @order.order_number, text_part.body.to_s
  end

  test "confirmation_email includes order total" do
    email = OrderMailer.with(order: @order).confirmation_email

    # Format as currency
    total = sprintf("%.2f", @order.total_amount)
    assert_match total, email.body.encoded
  end

  # The discount must appear on the customer email (it previously did not, so a
  # coupon order showed a Total that didn't reconcile with subtotal+shipping+VAT).
  # Both the HTML and text parts render via OrderSummary, so both must carry it.
  test "confirmation_email shows the discount line when the order has a discount" do
    @order.update!(discount_amount: 9.27, discount_code: "WELCOME10")
    email = OrderMailer.with(order: @order).confirmation_email

    # The PDF attachment wraps the multipart/alternative, so reach the parts via it.
    content_part = email.parts.find { |p| p.content_type.include?("multipart/alternative") } || email
    %w[text/html text/plain].each do |type|
      part = content_part.parts.find { |p| p.content_type.include?(type) }
      assert_match "Discount (WELCOME10)", part.body.to_s, "#{type} part missing discount label"
      assert_match "-£9.27", part.body.to_s, "#{type} part missing negative discount amount"
    end
  end

  test "confirmation_email omits the discount line when there is no discount" do
    # orders(:one) has the default zero discount_amount.
    email = OrderMailer.with(order: @order).confirmation_email

    assert_no_match(/Discount/, email.body.encoded)
  end

  test "confirmation_email can be delivered" do
    assert_nothing_raised do
      OrderMailer.with(order: @order).confirmation_email.deliver_now
    end
  end

  test "confirmation_email uses correct from address" do
    email = OrderMailer.with(order: @order).confirmation_email

    assert_not_nil email.from
    assert email.from.any?
  end

  test "confirmation_email with order that has items" do
    # Order fixture should have order_items
    assert @order.order_items.any?, "Order fixture should have items"

    email = OrderMailer.with(order: @order).confirmation_email

    # Email should be generated successfully
    assert_not_nil email
    assert_equal [ @order.email ], email.to
  end

  test "confirmation_email has pdf attachment with correct filename" do
    email = OrderMailer.with(order: @order).confirmation_email

    # Find the PDF attachment
    pdf_attachment = email.attachments.find { |a| a.content_type.include?("application/pdf") }
    assert_not_nil pdf_attachment, "Email should have PDF attachment"

    # Verify filename matches order number
    assert_equal "Order-#{@order.order_number}.pdf", pdf_attachment.filename
  end

  test "confirmation_email pdf attachment has content" do
    email = OrderMailer.with(order: @order).confirmation_email

    pdf_attachment = email.attachments.find { |a| a.content_type.include?("application/pdf") }
    assert_not_nil pdf_attachment

    # PDF should have content
    assert pdf_attachment.body.raw_source.length > 0, "PDF attachment should have content"

    # Verify it starts with PDF magic bytes
    assert pdf_attachment.body.raw_source.start_with?("%PDF"), "Attachment should be valid PDF"
  end

  test "confirmation_email sends without pdf if generation fails" do
    # Stub the generator to raise an error
    OrderPdfGenerator.any_instance.stubs(:generate).raises(StandardError, "Test error")

    email = OrderMailer.with(order: @order).confirmation_email

    # Email should still be deliverable
    assert_not_nil email
    assert_equal [ @order.email ], email.to

    # Should have no PDF attachment
    pdf_attachment = email.attachments.find { |a| a.content_type.include?("application/pdf") }
    assert_nil pdf_attachment, "Email should not have PDF attachment when generation fails"
  end

  # --- Customer email no longer BCCs ops ---

  test "confirmation_email no longer BCCs the ops address" do
    email = OrderMailer.with(order: @order).confirmation_email

    assert_empty Array(email.bcc), "Customer confirmation should not BCC ops anymore"
  end

  # --- Internal ops confirmation email ---

  test "ops_confirmation_email is sent to the ops address only" do
    email = OrderMailer.with(order: @order).ops_confirmation_email

    assert_equal [ "orders@afida.com" ], email.to
    assert_empty Array(email.bcc)
  end

  test "ops_confirmation_email subject is ops-flavored with order number and customer name" do
    email = OrderMailer.with(order: @order).ops_confirmation_email

    assert_equal "[OPS] Order ##{@order.order_number} - #{@order.shipping_name}", email.subject
  end

  test "ops_confirmation_email includes our SKU and supplier SKU in parentheses" do
    product = products(:one)
    assert product.supplier_sku.present?, "Fixture product should have a supplier SKU"

    email = OrderMailer.with(order: @order).ops_confirmation_email
    body = email.body.encoded

    assert_match product.sku, body
    assert_match "(#{product.supplier_sku})", body
  end

  test "ops_confirmation_email includes the full shipping address" do
    email = OrderMailer.with(order: @order).ops_confirmation_email
    body = email.body.encoded

    assert_match @order.shipping_name, body
    assert_match @order.shipping_address_line1, body
    assert_match @order.shipping_city, body
    assert_match @order.shipping_postal_code, body
    assert_match @order.email, body
  end

  test "ops_confirmation_email links to the admin order page" do
    email = OrderMailer.with(order: @order).ops_confirmation_email

    assert_match admin_order_url(@order, host: "example.com"), email.body.encoded
  end

  test "ops_confirmation_email drops customer pleasantries" do
    email = OrderMailer.with(order: @order).ops_confirmation_email
    body = email.body.encoded

    assert_no_match(/Thanks for choosing Afida/i, body)
    assert_no_match(/View Your Order/i, body)
  end

  test "ops_confirmation_email includes order total" do
    email = OrderMailer.with(order: @order).ops_confirmation_email

    total = sprintf("%.2f", @order.total_amount)
    assert_match total, email.body.encoded
  end

  # The ops email must also show the discount so staff can see why the total is
  # lower than subtotal + shipping + VAT. Both parts render via OrderSummary.
  test "ops_confirmation_email shows the discount line when the order has a discount" do
    @order.update!(discount_amount: 9.27, discount_code: "WELCOME10")
    email = OrderMailer.with(order: @order).ops_confirmation_email

    content_part = email.parts.find { |p| p.content_type.include?("multipart/alternative") } || email
    %w[text/html text/plain].each do |type|
      part = content_part.parts.find { |p| p.content_type.include?(type) }
      assert_match "Discount (WELCOME10)", part.body.to_s, "#{type} part missing discount label"
      assert_match "-£9.27", part.body.to_s, "#{type} part missing negative discount amount"
    end
  end

  test "ops_confirmation_email has both HTML and text parts" do
    email = OrderMailer.with(order: @order).ops_confirmation_email

    content_part = email.parts.find { |p| p.content_type.include?("multipart/alternative") } || email
    html_part = content_part.parts.find { |p| p.content_type.include?("text/html") }
    text_part = content_part.parts.find { |p| p.content_type.include?("text/plain") }

    assert_not_nil html_part, "Should have HTML part"
    assert_not_nil text_part, "Should have text part"
  end

  test "ops_confirmation_email can be delivered" do
    assert_emails 1 do
      OrderMailer.with(order: @order).ops_confirmation_email.deliver_now
    end
  end

  test "ops_confirmation_email renders when a line item's product is unavailable" do
    OrderItem.any_instance.stubs(:product).returns(nil)

    assert_nothing_raised do
      OrderMailer.with(order: @order).ops_confirmation_email.deliver_now
    end
  end
end
