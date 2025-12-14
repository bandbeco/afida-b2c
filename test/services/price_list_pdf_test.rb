# frozen_string_literal: true

require "test_helper"

class PriceListPdfTest < ActiveSupport::TestCase
  def setup
    @variants = ProductVariant.active
                              .joins(:product)
                              .where(products: { product_type: "standard", active: true })
                              .includes(product: :category)
                              .limit(10)
    @filter_description = "All products"
  end

  test "initializes with valid variants and filter description" do
    pdf = PriceListPdf.new(@variants, @filter_description)
    assert_not_nil pdf
  end

  test "generates pdf successfully" do
    pdf = PriceListPdf.new(@variants, @filter_description)
    pdf_data = pdf.render

    assert_not_nil pdf_data
    assert pdf_data.is_a?(String)
    assert pdf_data.length > 0
  end

  test "pdf starts with valid PDF header" do
    pdf = PriceListPdf.new(@variants, @filter_description)
    pdf_data = pdf.render

    # PDF files start with %PDF-
    assert pdf_data.start_with?("%PDF-"), "PDF should start with %PDF- header"
  end

  test "generates pdf with empty variants" do
    pdf = PriceListPdf.new([], @filter_description)
    pdf_data = pdf.render

    assert_not_nil pdf_data
    assert pdf_data.length > 0
  end

  test "generates pdf with filtered description" do
    pdf = PriceListPdf.new(@variants, "Filtered by: Cups & Lids")
    pdf_data = pdf.render

    assert_not_nil pdf_data
    assert pdf_data.length > 0
  end

  test "logo file exists at configured path" do
    logo_path = Rails.root.join(PriceListPdf::LOGO_PATH)
    assert File.exist?(logo_path), "Logo file should exist at #{logo_path}"
  end

  test "pdf file size is reasonable" do
    pdf = PriceListPdf.new(@variants, @filter_description)
    pdf_data = pdf.render

    file_size_kb = pdf_data.bytesize / 1024.0
    assert file_size_kb < 1000, "PDF size #{file_size_kb.round(2)}KB should be under 1MB"
  end

  test "class constants are defined" do
    assert_equal 65, PriceListPdf::LOGO_HEIGHT
    assert_equal 50, PriceListPdf::PAGE_MARGIN_BOTTOM
    assert_equal 40, PriceListPdf::FOOTER_LINE_Y
    assert_equal 20, PriceListPdf::FOOTER_TEXT_Y
    assert_equal 30, PriceListPdf::FOOTER_LEFT_PADDING
    assert PriceListPdf::VALUE_PROPOSITIONS.present?
    assert PriceListPdf::CONTACT_INFO.present?
  end

  test "value propositions contains key messaging" do
    assert_includes PriceListPdf::VALUE_PROPOSITIONS, "Free UK delivery"
    assert_includes PriceListPdf::VALUE_PROPOSITIONS, "Low MOQs"
    assert_includes PriceListPdf::VALUE_PROPOSITIONS, "48-hour delivery"
  end

  test "contact info contains required details" do
    assert_includes PriceListPdf::CONTACT_INFO, "afida.com"
    assert_includes PriceListPdf::CONTACT_INFO, "hello@afida.com"
    assert_includes PriceListPdf::CONTACT_INFO, "0203 302 7719"
  end
end
