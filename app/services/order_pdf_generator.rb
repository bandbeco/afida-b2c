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

  # Address block typography, shared by add_address_block (render) and
  # address_block_height (measure) so the measured bounding box can never
  # drift from what is drawn - an undersized box makes Prawn treat its bottom
  # as a page edge and break the whole layout onto a second page.
  SECTION_HEADER_SIZE = 11
  ADDRESS_LINE_SIZE = 10
  ADDRESS_TITLE_GAP = 8
  ADDRESS_NAME_GAP = 3
  ADDRESS_BLOCK_GAP = 10
  BORDER_GRAY = "E5E7EB".freeze        # Subtle borders

  HEADER_LINE_HEIGHT = 12
  SAME_AS_BILLING_NOTE = "Same as billing address"
  VAT_NOTE = "Prices exclude VAT. VAT at #{(VAT_RATE * 100).round}% is charged on goods and delivery."

  COMPANY_NAME = "Afida".freeze
  COMPANY_EMAIL = ENV.fetch("ORDERS_EMAIL", "orders@afida.com").freeze
  LOGO_PATH = Rails.root.join("app", "frontend", "images", "afida-logo-pdf.png").freeze

  FONT_DIR = Rails.root.join("app/frontend/fonts/fredoka/static")
  FONT_REGULAR = FONT_DIR.join("Fredoka-Regular.ttf").to_s.freeze
  FONT_BOLD = FONT_DIR.join("Fredoka-Medium.ttf").to_s.freeze

  def initialize(order)
    @order = order
  end

  def generate
    raise StandardError, "Order must have items" if @order.order_items.empty?

    Prawn::Document.new(page_size: "A4", margin: [ 40, 50, 40, 50 ]) do |pdf|
      setup_fonts(pdf)

      # Set default font color
      pdf.fill_color TEXT_DARK

      # Header with logo and accent bar
      add_header(pdf)
      pdf.move_down 25

      add_invoice_banner(pdf)
      pdf.move_down 20

      add_details_section(pdf)
      pdf.move_down 25

      add_items_table(pdf)
      pdf.move_down 8
      add_vat_note(pdf)
      pdf.move_down 12

      # Price summary
      add_price_summary(pdf)

      # Footer at bottom
      add_footer(pdf)
    end.render
  end

  private

  def setup_fonts(pdf)
    pdf.font_families.update(
      "Fredoka" => {
        normal: FONT_REGULAR,
        bold: FONT_BOLD
      }
    )
    pdf.font "Fredoka"
  end

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

    # Seller identity on the right: a VAT invoice must name the legal entity,
    # its address and VAT number, so these replace the old tagline.
    info_width = 220
    info_lines = seller_lines
    info_lines.each_with_index do |line, index|
      pdf.fill_color(index.zero? ? TEXT_DARK : TEXT_GRAY)
      pdf.text_box line, at: [ pdf.bounds.width - info_width, header_top - 2 - index * HEADER_LINE_HEIGHT ],
        width: info_width, size: 9, align: :right
    end

    pdf.move_down [ logo_height, info_lines.size * HEADER_LINE_HEIGHT ].max + 10

    # Accent line below header
    pdf.stroke_color PRIMARY_COLOR
    pdf.line_width = 3
    pdf.stroke_horizontal_line 0, pdf.bounds.width
    pdf.line_width = 1
    pdf.stroke_color "000000"

    pdf.fill_color TEXT_DARK
  end

  def seller_lines
    [
      CompanyDetails.legal_name_line,
      *CompanyDetails::ADDRESS_LINES,
      "VAT No. #{CompanyDetails::VAT_NUMBER}",
      "Company No. #{CompanyDetails::COMPANY_NUMBER}",
      COMPANY_EMAIL
    ]
  end

  def add_invoice_banner(pdf)
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
      pdf.text "Invoice", size: 18, style: :bold

      pdf.bounding_box([ pdf.bounds.width - 200, 22 ], width: 200, height: 25) do
        pdf.fill_color TEXT_GRAY
        pdf.text @order.invoice_number, size: 14, style: :bold, align: :right
      end
    end

    pdf.fill_color TEXT_DARK
  end

  def add_details_section(pdf)
    column_width = (pdf.bounds.width - 30) / 2
    blocks = address_blocks
    # Both columns share the measured height so they stay aligned. The height
    # is measured from the same lines that render (as add_price_summary sizes
    # from its row count).
    section_height = address_section_height(pdf, column_width, blocks)

    pdf.bounding_box([ 0, pdf.cursor ], width: column_width, height: section_height) do
      add_section_header(pdf, "Invoice Details")
      pdf.move_down 8

      add_detail_row(pdf, "Invoice No.", @order.invoice_number)
      add_detail_row(pdf, "Invoice Date", @order.created_at.strftime("%d %B %Y"))
      add_detail_row(pdf, "Order No.", @order.order_number)
      add_detail_row(pdf, "Payment", payment_status)
      add_detail_row(pdf, "Email", @order.email) if @order.email.present?
    end

    pdf.bounding_box([ column_width + 30, pdf.cursor + section_height ], width: column_width, height: section_height) do
      blocks.each_with_index do |(title, lines), index|
        pdf.move_down ADDRESS_BLOCK_GAP if index.positive?
        add_address_block(pdf, title, lines)
      end
    end

    pdf.fill_color TEXT_DARK
  end

  # The invoice is paid at checkout (or charged on the reorder schedule), so
  # the tax point is the order date and the status reads "Paid". Later
  # statuses (processing, shipped, delivered) are fulfilment, not payment.
  # The generator runs at order creation only; a refunded or cancelled order
  # would need a credit note, which this document is not.
  def payment_status
    return "Paid" if Order::COMPLETED_STATUSES.include?(@order.status)

    @order.status.titleize
  end

  # Bill-to is the collected billing address when it differs from delivery;
  # otherwise the delivery address is the invoiced party (orders predating
  # billing collection, or same-as-delivery). The second block then only
  # notes the match instead of repeating the address. Same-as-delivery is
  # judged on the address alone, so the billing name (the invoiced party,
  # e.g. the company) still replaces the delivery recipient when present.
  def address_blocks
    shipping_lines = OrderAddress.shipping_lines(@order)
    billing_lines = OrderAddress.billing_lines(@order)
    separate_billing = billing_lines.any? { |line| line[:kind] == :address }

    if separate_billing
      [ [ "Bill to", billing_lines ], [ "Deliver to", shipping_lines ] ]
    else
      [ [ "Bill to", bill_to_lines(shipping_lines) ], [ "Deliver to", [ { kind: :note, text: SAME_AS_BILLING_NOTE } ] ] ]
    end
  end

  def bill_to_lines(shipping_lines)
    return shipping_lines if @order.billing_name.blank?

    [ { kind: :name, text: @order.billing_name }, *shipping_lines.reject { |line| line[:kind] == :name } ]
  end

  # Only :name lines get the dark emphasis and trailing gap; :address and
  # :note lines (incl. the same-as-delivery note) render plain gray, matching
  # the other surfaces.
  def add_address_block(pdf, title, lines)
    add_section_header(pdf, title)
    pdf.move_down ADDRESS_TITLE_GAP

    lines.each do |line|
      name = line[:kind] == :name
      pdf.fill_color(name ? TEXT_DARK : TEXT_GRAY)
      pdf.text line[:text], size: ADDRESS_LINE_SIZE
      pdf.move_down ADDRESS_NAME_GAP if name
    end
  end

  # Measured height of the right column's content, with the left column's
  # fixed rows as the floor. height_of wraps against the column width, so long
  # address lines that break count in full. The per-block ADDRESS_NAME_GAP is
  # an allowance: blocks without a :name line render without the gap, so the
  # box can only be over-sized, never under.
  def address_section_height(pdf, column_width, blocks)
    height = blocks.sum { |title, lines| address_block_height(pdf, title, lines, column_width) }
    height += ADDRESS_BLOCK_GAP * (blocks.size - 1)

    [ height + 4, 100 ].max
  end

  def address_block_height(pdf, title, lines, column_width)
    # Titles render bold (add_section_header); measure them bold too, or a
    # wrapping title would be undercounted.
    pdf.height_of(title, size: SECTION_HEADER_SIZE, style: :bold, width: column_width) +
      ADDRESS_TITLE_GAP +
      lines.sum { |line| pdf.height_of(line[:text], size: ADDRESS_LINE_SIZE, width: column_width) } +
      ADDRESS_NAME_GAP
  end

  # HMRC wants the VAT rate per item; every line is standard-rated, so one
  # statement covers the table.
  def add_vat_note(pdf)
    pdf.fill_color TEXT_GRAY
    pdf.text VAT_NOTE, size: 8
    pdf.fill_color TEXT_DARK
  end

  def add_section_header(pdf, title)
    pdf.fill_color PRIMARY_DARK
    pdf.text title, size: SECTION_HEADER_SIZE, style: :bold
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
        item.sample? ? "FREE" : format_currency(item.line_total)
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

    # Lines, order, labels and the discount rule come from OrderSummary (shared
    # with the storefront pages, the admin page and the confirmation emails) so
    # the PDF can never drift. The amounts are already GBP-formatted there.
    lines = OrderSummary.lines(@order)
    detail_lines = lines.reject { |l| l[:kind] == :total }
    total_line = lines.find { |l| l[:kind] == :total }

    # Size the box from the row count so an optional discount row never overflows:
    # each detail row is 18pt, plus the divider gap (13pt) and the total row (~22pt).
    inner_height = detail_lines.size * 18 + 35
    box_height = inner_height + 20

    pdf.bounding_box([ pdf.bounds.width - summary_width, pdf.cursor ], width: summary_width, height: box_height + 10) do
      # Background box
      pdf.fill_color LIGHT_GRAY
      pdf.fill_rounded_rectangle([ 0, pdf.cursor ], summary_width, box_height, 6)

      pdf.bounding_box([ 15, pdf.cursor - 15 ], width: summary_width - 30, height: inner_height) do
        detail_lines.each do |line|
          add_summary_row(pdf, line[:label], line[:amount], negative: line[:negative])
        end

        pdf.move_down 5
        pdf.stroke_color BORDER_GRAY
        pdf.stroke_horizontal_line 0, summary_width - 30
        pdf.move_down 8

        # Total row - emphasized
        pdf.fill_color TEXT_DARK
        pdf.text_box total_line[:label], at: [ 0, pdf.cursor ], width: 80, size: 12, style: :bold
        pdf.fill_color PRIMARY_DARK
        pdf.text_box total_line[:amount],
          at: [ 80, pdf.cursor ], width: summary_width - 110, size: 14, style: :bold, align: :right
      end
    end

    pdf.fill_color TEXT_DARK
  end

  # Renders one summary row. amount is already GBP-formatted (incl. the leading
  # "-" for the discount). A negative (discount) amount is drawn in the brand mint
  # to read as a saving, since Prawn has no themed "success" colour.
  def add_summary_row(pdf, label, amount, negative: false)
    pdf.fill_color TEXT_GRAY
    pdf.text_box label, at: [ 0, pdf.cursor ], width: 100, size: 10
    pdf.fill_color(negative ? PRIMARY_DARK : TEXT_DARK)
    pdf.text_box amount, at: [ 100, pdf.cursor ], width: 90, size: 10, align: :right
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
      size: 10, align: :center
    pdf.move_down 8

    pdf.text "Questions? Contact us at #{COMPANY_EMAIL}",
      size: 9, align: :center

    pdf.fill_color TEXT_DARK
  end

  def format_currency(amount)
    "£#{ActiveSupport::NumberHelper.number_to_delimited(format('%.2f', amount))}"
  end

  # Formats product name with units per pack on second line
  # Adds "(Sample)" indicator for sample items
  def format_product_name(item)
    name = item.product_name
    name = "#{name} (Sample)" if item.sample?

    if item.pac_size.present? && item.pac_size > 1
      units_per_pack = ActiveSupport::NumberHelper.number_to_delimited(item.pac_size)
      "#{name}\n(#{units_per_pack} units / pack)"
    else
      name
    end
  end

  # Formats unit price with 4 decimal precision for accurate per-unit pricing
  def format_unit_price(amount)
    "£%.4f" % amount
  end

  # Formats quantity display for order items
  # Samples: "1 unit" - samples are always single units
  # Pack-priced items: "30 packs (15,000 units)" - quantity IS packs, units = quantity * pac_size
  # Unit-priced items: "5,000 units" - quantity IS units
  def format_quantity_display(item)
    if item.sample?
      "#{item.quantity} #{'unit'.pluralize(item.quantity)}"
    elsif item.pack_priced?
      # quantity is number of packs, calculate total units
      packs = item.quantity
      total_units = packs * item.pac_size
      packs_formatted = ActiveSupport::NumberHelper.number_to_delimited(packs)
      units_formatted = ActiveSupport::NumberHelper.number_to_delimited(total_units)
      "#{packs_formatted} #{'pack'.pluralize(packs)}\n(#{units_formatted} units)"
    else
      units = ActiveSupport::NumberHelper.number_to_delimited(item.quantity)
      "#{units} #{'unit'.pluralize(item.quantity)}"
    end
  end

  # Formats price display for order items
  # Samples: "£0.00 / unit"
  # Pack-priced items: "£15.99 / pack (£0.0320 / unit)"
  # Unit-priced items: "£0.0320 / unit"
  def format_price_display(item)
    return "£0.00 / unit" if item.sample?

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
