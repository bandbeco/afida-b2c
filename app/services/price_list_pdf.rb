# frozen_string_literal: true

class PriceListPdf < Prawn::Document
  include ActionView::Helpers::NumberHelper

  def initialize(variants, filter_description)
    super(page_size: "A4", page_layout: :landscape, margin: 30)
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
    text "Afida Price List", size: 24, style: :bold
    move_down 5
    text @filter_description, size: 10, color: "666666"
    text "Generated: #{Date.current.strftime('%d %B %Y')}", size: 10, color: "666666"
    text "All prices exclude VAT", size: 10, color: "666666"
    move_down 15
  end

  def price_table
    return if @variants.empty?

    table_data = [
      [ "Product", "SKU", "Size", "Material", "Pack Size", "Price/Pack", "Price/Unit" ]
    ]

    @variants.each do |variant|
      table_data << [
        variant.product.name,
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
    number_pages "Page <page> of <total>", at: [ bounds.right - 100, 0 ], size: 9
  end
end
