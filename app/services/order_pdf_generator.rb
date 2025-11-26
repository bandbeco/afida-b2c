require "prawn"
require "prawn/table"

class OrderPdfGenerator
  COMPANY_NAME = "Afida".freeze
  COMPANY_TAGLINE = "Eco-Friendly Catering Supplies".freeze
  COMPANY_EMAIL = ENV.fetch("ORDERS_EMAIL", "orders@afida.com").freeze
  LOGO_PATH = Rails.root.join("app", "frontend", "images", "logo.png").freeze

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
    if File.exist?(LOGO_PATH) && File.size(LOGO_PATH) > 0
      begin
        pdf.image LOGO_PATH, width: 120, position: :left
        pdf.move_down 10
      rescue StandardError => e
        Rails.logger.warn("Failed to add logo to PDF: #{e.message}")
      end
    end

    pdf.text COMPANY_NAME, size: 24, style: :bold
    pdf.text COMPANY_TAGLINE, size: 12, style: :italic
    pdf.move_down 5
    pdf.text COMPANY_EMAIL, size: 10
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

    pdf.text @order.shipping_name.to_s, size: 10
    pdf.text @order.shipping_address_line1.to_s, size: 10
    pdf.text @order.shipping_address_line2.to_s, size: 10 if @order.shipping_address_line2.present?
    pdf.text "#{@order.shipping_city}, #{@order.shipping_postal_code}".strip, size: 10
    pdf.text @order.shipping_country.to_s, size: 10
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
        format_quantity_display(item),
        format_price_display(item),
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
    pdf.text "If you have any questions, please contact us at #{COMPANY_EMAIL}",
      size: 9, align: :center
  end

  def format_currency(amount)
    "£%.2f" % amount
  end

  # Formats quantity display for order items
  # Pack-priced items: "30 packs (15,000 units)"
  # Unit-priced items: "5,000 units"
  def format_quantity_display(item)
    if item.pack_priced?
      packs = (item.quantity.to_f / item.pac_size).ceil
      units = ActiveSupport::NumberHelper.number_to_delimited(item.quantity)
      packs_formatted = ActiveSupport::NumberHelper.number_to_delimited(packs)
      "#{packs_formatted} #{'pack'.pluralize(packs)}\n(#{units} units)"
    else
      units = ActiveSupport::NumberHelper.number_to_delimited(item.quantity)
      "#{units} units"
    end
  end

  # Formats price display for order items
  # Pack-priced items: "£15.99 / pack (£0.0320 / unit)"
  # Unit-priced items: "£0.0320 / unit"
  def format_price_display(item)
    if item.pack_priced?
      pack = format_currency(item.pack_price)
      unit = "£%.4f" % item.unit_price
      "#{pack} / pack\n(#{unit} / unit)"
    else
      unit = "£%.4f" % item.unit_price
      "#{unit} / unit"
    end
  end
end
