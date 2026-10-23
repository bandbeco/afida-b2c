# frozen_string_literal: true

# The seller's legal identity: one spelling for the invoice, the structured
# data, the footer and the terms. Company number verified against Companies
# House (B&B ECO LTD, incorporated 4 October 2020, registered at the Watford
# address below); VAT number verified valid on the gov.uk VAT checker on
# 2026-10-22. Both are public, so they live here.
module CompanyDetails
  LEGAL_NAME = "B&B Eco Ltd"
  SHORT_NAME = "B&B Eco"
  TRADING_NAME = "Afida"
  COMPANY_NUMBER = "12927067"
  VAT_NUMBER = "GB372516007"

  STREET = "Unit 27, The Metro Centre, Dwight Rd"
  LOCALITY = "Watford"
  REGION = "Hertfordshire"
  POSTCODE = "WD18 9SB"
  COUNTRY_CODE = "GB"
  COUNTRY_NAME = "United Kingdom"

  ADDRESS_LINES = [ STREET, "#{LOCALITY} #{POSTCODE}, #{COUNTRY_NAME}" ].freeze

  def self.legal_name_line
    "#{LEGAL_NAME}, trading as #{TRADING_NAME}"
  end

  def self.postal_address
    [ STREET, LOCALITY, REGION, POSTCODE ].join(", ")
  end
end
