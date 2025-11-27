require "prawn"
require "prawn/table"

class OrderPdfGenerator
  # Brand colors (Prawn hex format without #)
  PRIMARY_COLOR = "79EBC0".freeze      # Mint green
  PRIMARY_DARK = "5FD9A8".freeze       # Darker mint for contrast
  SECONDARY_COLOR = "FF6B9D".freeze    # Pink accent
  TEXT_DARK = "1F2937".freeze          # Near black for headings
  TEXT_GRAY = "6B7280".freeze          # Gray for secondary text
  LIGHT_GRAY = "F3F4F6".freeze         # Table alternating row
  BORDER_GRAY = "E5E7EB".freeze        # Subtle borders

  COMPANY_NAME = "Afida".freeze
  COMPANY_TAGLINE = "Eco-Friendly Catering Supplies".freeze
  COMPANY_EMAIL = ENV.fetch("ORDERS_EMAIL", "orders@afida.com").freeze
  COMPANY_WEBSITE = "https://afida.com".freeze
  LOGO_PATH = Rails.root.join("app", "frontend", "images", "afida-logo.png").freeze

  def initialize(order)
    @order = order
  end

  def generate
    raise StandardError, "Order must have items" if @order.order_items.empty?

    Prawn::Document.new(page_size: "A4", margin: [ 40, 50, 40, 50 ]) do |pdf|
      # Set default font color
      pdf.fill_color TEXT_DARK

      # Header with logo and accent bar
      add_header(pdf)
      pdf.move_down 25

      # Order confirmation banner
      add_confirmation_banner(pdf)
      pdf.move_down 20

      # Two-column: Order details + Shipping address
      add_details_section(pdf)
      pdf.move_down 25

      # Order items table
      add_items_table(pdf)
      pdf.move_down 20

      # Price summary
      add_price_summary(pdf)

      # Footer at bottom
      add_footer(pdf)
    end.render
  end

  private

  def add_header(pdf)
    header_top = pdf.cursor
    logo_height = 40

    # Logo on left
    if File.exist?(LOGO_PATH) && File.size(LOGO_PATH) > 0
      begin
        pdf.image LOGO_PATH, at: [ 0, header_top ], height: logo_height
      rescue StandardError => e
        Rails.logger.warn("Failed to add logo to PDF: #{e.message}")
        # Fallback to text logo
        pdf.fill_color PRIMARY_DARK
        pdf.draw_text COMPANY_NAME, at: [ 0, header_top - 25 ], size: 24, style: :bold
      end
    else
      pdf.fill_color PRIMARY_DARK
      pdf.draw_text COMPANY_NAME, at: [ 0, header_top - 25 ], size: 24, style: :bold
    end

    # Company info on right side (right-aligned)
    info_width = 180
    pdf.fill_color TEXT_GRAY
    pdf.text_box COMPANY_TAGLINE, at: [ pdf.bounds.width - info_width, header_top - 2 ], width: info_width, size: 9, align: :right
    pdf.text_box COMPANY_EMAIL, at: [ pdf.bounds.width - info_width, header_top - 14 ], width: info_width, size: 9, align: :right
    pdf.text_box COMPANY_WEBSITE, at: [ pdf.bounds.width - info_width, header_top - 26 ], width: info_width, size: 9, align: :right

    # Move cursor below header
    pdf.move_down logo_height + 10

    # Accent line below header
    pdf.stroke_color PRIMARY_COLOR
    pdf.line_width = 3
    pdf.stroke_horizontal_line 0, pdf.bounds.width
    pdf.line_width = 1
    pdf.stroke_color "000000"

    pdf.fill_color TEXT_DARK
  end

  def add_confirmation_banner(pdf)
    banner_height = 50

    # Draw rounded rectangle background
    pdf.fill_color LIGHT_GRAY
    pdf.fill_rounded_rectangle([ 0, pdf.cursor ], pdf.bounds.width, banner_height, 8)

    # Add green accent on left edge
    pdf.fill_color PRIMARY_COLOR
    pdf.fill_rounded_rectangle([ 0, pdf.cursor ], 6, banner_height, 3)

    # Banner content
    pdf.bounding_box([ 20, pdf.cursor - 10 ], width: pdf.bounds.width - 40, height: banner_height - 20) do
      pdf.fill_color TEXT_DARK
      pdf.text "Order Confirmation", size: 18, style: :bold

      # Order number on the right
      pdf.bounding_box([ pdf.bounds.width - 200, 22 ], width: 200, height: 25) do
        pdf.fill_color TEXT_GRAY
        pdf.text @order.order_number, size: 14, style: :bold, align: :right
      end
    end

    pdf.fill_color TEXT_DARK
  end

  def add_details_section(pdf)
    column_width = (pdf.bounds.width - 30) / 2
    section_height = 100

    # Left column: Order details
    pdf.bounding_box([ 0, pdf.cursor ], width: column_width, height: section_height) do
      add_section_header(pdf, "Order Details")
      pdf.move_down 8

      add_detail_row(pdf, "Order Number", @order.order_number)
      add_detail_row(pdf, "Order Date", @order.created_at.strftime("%d %B %Y"))
      add_detail_row(pdf, "Status", @order.status.titleize)
      add_detail_row(pdf, "Email", @order.email) if @order.email.present?
    end

    # Right column: Shipping address
    pdf.bounding_box([ column_width + 30, pdf.cursor + section_height ], width: column_width, height: section_height) do
      add_section_header(pdf, "Shipping Address")
      pdf.move_down 8

      pdf.fill_color TEXT_DARK
      pdf.text @order.shipping_name.to_s, size: 10, style: :bold
      pdf.move_down 3
      pdf.fill_color TEXT_GRAY
      pdf.text @order.shipping_address_line1.to_s, size: 10
      pdf.text @order.shipping_address_line2.to_s, size: 10 if @order.shipping_address_line2.present?
      pdf.text "#{@order.shipping_city}, #{@order.shipping_postal_code}".strip, size: 10
      pdf.text @order.shipping_country.to_s, size: 10
    end

    pdf.fill_color TEXT_DARK
  end

  def add_section_header(pdf, title)
    pdf.fill_color PRIMARY_DARK
    pdf.text title, size: 11, style: :bold
    pdf.fill_color TEXT_DARK
  end

  def add_detail_row(pdf, label, value)
    pdf.fill_color TEXT_GRAY
    pdf.text_box "#{label}:", at: [ 0, pdf.cursor ], width: 90, size: 9
    pdf.fill_color TEXT_DARK
    pdf.text_box value.to_s, at: [ 95, pdf.cursor ], width: 150, size: 9, style: :bold
    pdf.move_down 14
  end

  def add_items_table(pdf)
    add_section_header(pdf, "Order Items")
    pdf.move_down 10

    table_data = [
      [ "Product", "SKU", "Quantity", "Unit Price", "Total" ]
    ]

    @order.order_items.each do |item|
      table_data << [
        format_product_name(item),
        item.product_sku,
        format_quantity_display(item),
        format_price_display(item),
        format_currency(item.line_total)
      ]
    end

    pdf.table(table_data,
      header: true,
      width: pdf.bounds.width,
      cell_style: {
        size: 9,
        padding: [ 10, 8 ],
        border_width: 0.5,
        border_color: BORDER_GRAY,
        text_color: TEXT_DARK
      },
      column_widths: { 0 => 160, 1 => 75, 4 => 80 }
    ) do |table|
      # Header row styling
      table.row(0).font_style = :bold
      table.row(0).background_color = PRIMARY_COLOR
      table.row(0).text_color = TEXT_DARK
      table.row(0).padding = [ 12, 8 ]

      # Alternating row colors for data rows (apply to each row individually)
      (1...table_data.length).each do |i|
        table.row(i).background_color = i.odd? ? "FFFFFF" : LIGHT_GRAY
      end

      # Right-align price columns
      table.columns(3..4).align = :right
      table.column(2).align = :center
    end
  end

  def add_price_summary(pdf)
    summary_width = 220

    pdf.bounding_box([ pdf.bounds.width - summary_width, pdf.cursor ], width: summary_width, height: 120) do
      # Background box
      pdf.fill_color LIGHT_GRAY
      pdf.fill_rounded_rectangle([ 0, pdf.cursor ], summary_width, 110, 6)

      pdf.bounding_box([ 15, pdf.cursor - 15 ], width: summary_width - 30, height: 90) do
        add_summary_row(pdf, "Subtotal", @order.subtotal_amount)
        add_summary_row(pdf, "VAT (20%)", @order.vat_amount)
        add_summary_row(pdf, "Shipping", @order.shipping_amount)

        pdf.move_down 5
        pdf.stroke_color BORDER_GRAY
        pdf.stroke_horizontal_line 0, summary_width - 30
        pdf.move_down 8

        # Total row - emphasized
        pdf.fill_color TEXT_DARK
        pdf.text_box "Total", at: [ 0, pdf.cursor ], width: 80, size: 12, style: :bold
        pdf.fill_color PRIMARY_DARK
        pdf.text_box format_currency(@order.total_amount),
          at: [ 80, pdf.cursor ], width: summary_width - 110, size: 14, style: :bold, align: :right
      end
    end

    pdf.fill_color TEXT_DARK
  end

  def add_summary_row(pdf, label, amount)
    pdf.fill_color TEXT_GRAY
    pdf.text_box label, at: [ 0, pdf.cursor ], width: 100, size: 10
    pdf.fill_color TEXT_DARK
    pdf.text_box format_currency(amount), at: [ 100, pdf.cursor ], width: 90, size: 10, align: :right
    pdf.move_down 18
  end

  def add_footer(pdf)
    # Add some space before footer
    pdf.move_down 30

    # Divider line
    pdf.stroke_color BORDER_GRAY
    pdf.stroke_horizontal_line 0, pdf.bounds.width
    pdf.move_down 15

    # Thank you message
    pdf.fill_color PRIMARY_DARK
    pdf.text "Thank you for choosing Afida!", size: 14, style: :bold, align: :center
    pdf.move_down 6

    pdf.fill_color TEXT_GRAY
    pdf.text "Together we're making sustainable choices for a greener future.",
      size: 10, style: :italic, align: :center
    pdf.move_down 8

    pdf.text "Questions? Contact us at #{COMPANY_EMAIL}",
      size: 9, align: :center

    pdf.fill_color TEXT_DARK
  end

  def format_currency(amount)
    "£#{ActiveSupport::NumberHelper.number_to_delimited(format('%.2f', amount))}"
  end

  # Formats product name with units per pack on second line
  def format_product_name(item)
    if item.pac_size.present? && item.pac_size > 1
      units_per_pack = ActiveSupport::NumberHelper.number_to_delimited(item.pac_size)
      "#{item.product_name}\n(#{units_per_pack} units / pack)"
    else
      item.product_name
    end
  end

  # Formats unit price with 4 decimal precision for accurate per-unit pricing
  def format_unit_price(amount)
    "£%.4f" % amount
  end

  # Formats quantity display for order items
  # Pack-priced items: "30 packs (15,000 units)" - quantity IS packs, units = quantity * pac_size
  # Unit-priced items: "5,000 units" - quantity IS units
  def format_quantity_display(item)
    if item.pack_priced?
      # quantity is number of packs, calculate total units
      packs = item.quantity
      total_units = packs * item.pac_size
      packs_formatted = ActiveSupport::NumberHelper.number_to_delimited(packs)
      units_formatted = ActiveSupport::NumberHelper.number_to_delimited(total_units)
      "#{packs_formatted} #{'pack'.pluralize(packs)}\n(#{units_formatted} units)"
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
      unit = format_unit_price(item.unit_price)
      "#{pack} / pack\n(#{unit} / unit)"
    else
      unit = format_unit_price(item.unit_price)
      "#{unit} / unit"
    end
  end
end
