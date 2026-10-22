class OrderMailer < ApplicationMailer
  helper :orders

  OPS_EMAIL = "orders@afida.com".freeze

  def confirmation_email
    @order = params[:order]

    # The body only promises the invoice when the attachment made it on.
    @invoice_attached = attach_order_pdf(@order)

    mail(
      to: @order.email,
      subject: "Your Order ##{@order.order_number} is Confirmed!"
    )
  end

  # Internal ops copy of the order confirmation. Near-identical order data to the
  # customer email, plus supplier SKUs and the full shipping address, so admins can
  # forward it to suppliers / use it as a picking list.
  def ops_confirmation_email
    @order = params[:order]

    attach_order_pdf(@order)

    mail(
      to: OPS_EMAIL,
      subject: "[OPS] Order ##{@order.order_number} - #{@order.shipping_name}"
    )
  end

  private

  def attach_order_pdf(order)
    pdf_data = OrderPdfGenerator.new(order).generate
    attachments["Invoice-#{order.invoice_number}.pdf"] = {
      mime_type: "application/pdf",
      content: pdf_data
    }
    true
  rescue StandardError => e
    # The email still goes out, but the customer is then missing their VAT
    # invoice, so the failure is reported (Sentry) rather than only logged.
    Rails.logger.error("Failed to generate PDF for order #{order.order_number}: #{e.message}")
    Rails.error.report(e, handled: true, context: { order_id: order.id })
    false
  end
end
