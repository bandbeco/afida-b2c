class OrderMailer < ApplicationMailer
  default bcc: "orders@afida.com"

  def confirmation_email
    @order = params[:order]

    # Attach PDF if generation succeeds
    begin
      pdf_data = OrderPdfGenerator.new(@order).generate
      attachments["Order-#{@order.order_number}.pdf"] = {
        mime_type: "application/pdf",
        content: pdf_data
      }
    rescue StandardError => e
      # Log error but continue sending email
      Rails.logger.error("Failed to generate PDF for order #{@order.order_number}: #{e.message}")
    end

    mail(
      to: @order.email,
      subject: "Your Order ##{@order.order_number} is Confirmed!"
    )
  end
end
