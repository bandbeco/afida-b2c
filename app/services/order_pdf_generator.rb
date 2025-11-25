require "prawn"
require "prawn/table"

class OrderPdfGenerator
  def initialize(order)
    @order = order
  end

  def generate
    raise StandardError, "Order must have items" if @order.order_items.empty?

    Prawn::Document.new(page_size: "A4", margin: 40) do |pdf|
      # Header with logo and company info
      add_header(pdf)
      pdf.move_down 30

      # Order details
      add_order_info(pdf)
      pdf.move_down 20

      # Shipping details
      add_shipping_info(pdf)
      pdf.move_down 20

      # Order items table
      add_items_table(pdf)
      pdf.move_down 20

      # Price summary
      add_price_summary(pdf)
      pdf.move_down 30

      # Footer
      add_footer(pdf)
    end.render
  end

  private

  def add_header(pdf)
    logo_path = Rails.root.join("app", "frontend", "images", "logo.png")

    if File.exist?(logo_path)
      # Add logo (scaled down to fit)
      pdf.image logo_path, width: 120, position: :left
      pdf.move_down 10
    end

    pdf.text "Afida", size: 24, style: :bold
    pdf.text "Eco-Friendly Catering Supplies", size: 12, style: :italic
    pdf.move_down 5
    pdf.text "orders@afida.com", size: 10
  end

  def add_order_info(pdf)
    pdf.text "Order Confirmation", size: 18, style: :bold
    pdf.move_down 10

    pdf.text "Order Number: #{@order.order_number}", size: 12, style: :bold
    pdf.text "Order Date: #{@order.created_at.strftime('%B %d, %Y')}", size: 10
    pdf.text "Status: #{@order.status.titleize}", size: 10
  end

  def add_shipping_info(pdf)
    pdf.text "Shipping Address", size: 14, style: :bold
    pdf.move_down 5

    pdf.text @order.shipping_name, size: 10
    pdf.text @order.shipping_address_line1, size: 10
    pdf.text @order.shipping_address_line2, size: 10 if @order.shipping_address_line2.present?
    pdf.text "#{@order.shipping_city}, #{@order.shipping_postal_code}", size: 10
    pdf.text @order.shipping_country, size: 10
  end

  def add_items_table(pdf)
    pdf.text "Order Items", size: 14, style: :bold
    pdf.move_down 10

    table_data = [
      [ "Product", "SKU", "Qty", "Price", "Total" ]
    ]

    @order.order_items.each do |item|
      table_data << [
        item.product_name,
        item.product_sku,
        item.quantity.to_s,
        format_currency(item.price),
        format_currency(item.line_total)
      ]
    end

    pdf.table(table_data,
      header: true,
      width: pdf.bounds.width,
      cell_style: { size: 9, padding: [ 5, 10 ] },
      row_colors: [ "FFFFFF", "F5F5F5" ]) do
      row(0).font_style = :bold
      row(0).background_color = "CCCCCC"
      columns(3..4).align = :right
    end
  end

  def add_price_summary(pdf)
    summary_data = [
      [ "Subtotal:", format_currency(@order.subtotal_amount) ],
      [ "VAT (20%):", format_currency(@order.vat_amount) ],
      [ "Shipping:", format_currency(@order.shipping_amount) ],
      [ "Total:", format_currency(@order.total_amount) ]
    ]

    pdf.table(summary_data,
      position: :right,
      width: 200,
      cell_style: { borders: [], size: 10, padding: [ 2, 10 ] }) do
      column(1).align = :right
      row(-1).font_style = :bold
      row(-1).size = 12
    end
  end

  def add_footer(pdf)
    pdf.move_down 20
    pdf.stroke_horizontal_rule
    pdf.move_down 10

    pdf.text "Thank you for your order!", size: 12, style: :bold, align: :center
    pdf.text "If you have any questions, please contact us at orders@afida.com",
      size: 9, align: :center
  end

  def format_currency(amount)
    "£%.2f" % amount
  end
end
