module Checkout
  class StripeTaxRateProvider
    def tax_rate
      @tax_rate ||= find_or_create_uk_vat_rate
    end

    private

    def find_or_create_uk_vat_rate
      existing_rates = Stripe::TaxRate.list(active: true, limit: 100)
      uk_vat_rate = existing_rates.data.find do |rate|
        rate.percentage == 20.0 &&
          rate.country == "GB" &&
          rate.inclusive == false
      end

      uk_vat_rate || Stripe::TaxRate.create({
        display_name: "VAT",
        percentage: 20,
        country: "GB",
        jurisdiction: "United Kingdom",
        description: "Value Added Tax",
        inclusive: false
      })
    end
  end
end
