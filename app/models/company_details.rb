# frozen_string_literal: true

# The legal identity printed on customer invoices. Company number verified
# against Companies House (B&B ECO LTD, incorporated 4 October 2020,
# registered at the Watford address below); VAT number verified valid on the
# gov.uk VAT checker on 2026-10-22. Both are public, so they live here.
module CompanyDetails
  LEGAL_NAME = "B&B Eco Ltd"
  TRADING_NAME = "Afida"
  COMPANY_NUMBER = "12927067"
  VAT_NUMBER = "GB372516007"
  ADDRESS_LINES = [
    "Unit 27, The Metro Centre, Dwight Rd",
    "Watford WD18 9SB, United Kingdom"
  ].freeze

  def self.legal_name_line
    "#{LEGAL_NAME}, trading as #{TRADING_NAME}"
  end
end
