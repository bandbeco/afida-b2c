# frozen_string_literal: true

class PriceListPdf < Prawn::Document
  include ActionView::Helpers::NumberHelper

  # Layout constants
  PAGE_MARGIN_TOP = 30
  PAGE_MARGIN_RIGHT = 30
  PAGE_MARGIN_BOTTOM = 50  # Extra space reserved for footer
  PAGE_MARGIN_LEFT = 30

  # Header constants
  LOGO_HEIGHT = 65
  LOGO_PATH = "app/frontend/images/afida-logo-pdf.png"
  TITLE_X_POSITION = 400

  # Footer constants
  FOOTER_LINE_Y = 40
  FOOTER_TEXT_Y = 20
  FOOTER_LEFT_PADDING = 30
  FOOTER_PAGE_NUMBER_OFFSET = 80

  # Branding content
  VALUE_PROPOSITIONS = "Free UK delivery over £100 • Low MOQs • 48-hour delivery"
  CONTACT_INFO = "afida.com  •  hello@afida.com  •  0203 302 7719"

  def initialize(variants, filter_description)
    super(
      page_size: "A4",
      page_layout: :landscape,
      margin: [ PAGE_MARGIN_TOP, PAGE_MARGIN_RIGHT, PAGE_MARGIN_BOTTOM, PAGE_MARGIN_LEFT ]
    )
    @variants = variants
    @filter_description = filter_description

    generate
  end

  private

  def generate
    header
    price_table
    footer
  end

  def header
    logo_top = cursor

    # Logo on the left
    logo_path = Rails.root.join(LOGO_PATH)
    image logo_path, at: [ 0, logo_top ], height: LOGO_HEIGHT

    # Title and metadata on the right, aligned with logo
    bounding_box([ TITLE_X_POSITION, logo_top ], width: 400, height: LOGO_HEIGHT) do
      text "Price List", size: 20, style: :bold
      move_down 5
      text @filter_description, size: 10, color: "666666"
      text "Generated: #{Date.current.strftime('%d %B %Y')}", size: 10, color: "666666"
      text "All prices exclude VAT", size: 10, color: "666666"
    end

    # Move down to clear logo height
    move_down 20

    # Value propositions underneath the logo
    text VALUE_PROPOSITIONS, size: 11, style: :bold, color: "000000"

    move_down 15
  end

  def price_table
    return if @variants.empty?

    table_data = [
      [ "Product", "SKU", "Size", "Material", "Pack Size", "Price/Pack", "Price/Unit" ]
    ]

    @variants.each do |variant|
      table_data << [
        variant.full_name,
        variant.sku,
        variant.option_values["size"] || variant.name,
        variant.option_values["material"] || "-",
        number_with_delimiter(variant.pac_size || 1),
        number_to_currency(variant.price),
        number_to_currency(variant.unit_price, precision: 4)
      ]
    end

    # A4 landscape with 30pt margins = 841.89 - 60 = ~781 available width
    # Column widths must sum to this or less
    table(table_data, header: true, cell_style: { size: 9 }) do |t|
      t.row(0).font_style = :bold
      t.row(0).background_color = "4A5568"
      t.row(0).text_color = "FFFFFF"
      t.cells.padding = [ 4, 6 ]
      t.cells.borders = [ :bottom ]
      t.cells.border_color = "DDDDDD"
      t.column(0).width = 200
      t.column(1).width = 100
      t.column(2).width = 80
      t.column(3).width = 100
      t.column(4).width = 80
      t.column(4).align = :right
      t.column(5).width = 90
      t.column(5).align = :right
      t.column(6).width = 90
      t.column(6).align = :right
    end
  end

  def footer
    repeat(:all, dynamic: true) do
      canvas do
        # Horizontal separator line
        stroke do
          stroke_color "DDDDDD"
          line_width 1
          stroke_horizontal_line bounds.left, bounds.right, at: FOOTER_LINE_Y
        end

        # Contact information (left-aligned)
        draw_text CONTACT_INFO,
                  at: [ bounds.left + FOOTER_LEFT_PADDING, FOOTER_TEXT_Y ],
                  size: 9,
                  color: "666666"

        # Page numbers (right-aligned)
        draw_text "Page #{page_number} of #{page_count}",
                  at: [ bounds.right - FOOTER_PAGE_NUMBER_OFFSET, FOOTER_TEXT_Y ],
                  size: 9,
                  color: "666666"
      end
    end
  end
end
