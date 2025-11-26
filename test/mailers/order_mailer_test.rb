require "test_helper"

class OrderMailerTest < ActionMailer::TestCase
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

  test "confirmation_email includes BCC to orders email" do
    email = OrderMailer.with(order: @order).confirmation_email

    assert_includes email.bcc, "orders@afida.com"
  end

  test "confirmation_email body includes order number" do
    email = OrderMailer.with(order: @order).confirmation_email

    assert_match @order.order_number, email.body.encoded
  end

  test "confirmation_email body includes shipping name" do
    email = OrderMailer.with(order: @order).confirmation_email

    assert_match @order.shipping_name, email.body.encoded
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
end
