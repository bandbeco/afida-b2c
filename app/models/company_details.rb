# frozen_string_literal: true

# The legal identity printed on customer invoices. The VAT registration number
# is read from the environment (set in config/deploy.yml) rather than typed
# here: it is not recorded anywhere in the repo, and an invoice without it is
# not a VAT invoice, so the generator omits the line until it is configured.
# Company number verified against Companies House (B&B ECO LTD, incorporated
# 4 October 2020, registered at the Watford address below).
module CompanyDetails
  LEGAL_NAME = "B&B Eco Ltd"
  TRADING_NAME = "Afida"
  COMPANY_NUMBER = "12927067"
  ADDRESS_LINES = [
    "Unit 27, The Metro Centre, Dwight Rd",
    "Watford WD18 9SB, United Kingdom"
  ].freeze

  def self.vat_number
    ENV.fetch("COMPANY_VAT_NUMBER", "").strip
  end

  def self.legal_name_line
    "#{LEGAL_NAME}, trading as #{TRADING_NAME}"
  end
end
