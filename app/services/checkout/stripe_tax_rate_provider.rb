module Checkout
  class StripeTaxRateProvider
    UK_VAT_RATE_ID_CACHE_KEY = "checkout/stripe_tax_rate_provider/uk_vat_rate_id"
    UK_VAT_RATE_ID_CACHE_TTL = 1.hour
    TaxRateReference = Struct.new(:id)

    def tax_rate
      @tax_rate ||= cached_tax_rate || fetch_and_cache_tax_rate
    end

    private

    def cached_tax_rate
      tax_rate_id = Rails.cache.read(UK_VAT_RATE_ID_CACHE_KEY)
      TaxRateReference.new(tax_rate_id) if tax_rate_id.present?
    end

    def fetch_and_cache_tax_rate
      find_or_create_uk_vat_rate.tap do |tax_rate|
        Rails.cache.write(UK_VAT_RATE_ID_CACHE_KEY, tax_rate.id, expires_in: UK_VAT_RATE_ID_CACHE_TTL)
      end
    end

    def find_or_create_uk_vat_rate
      existing_rates = Stripe::TaxRate.list(active: true, limit: 100)
      uk_vat_rate = existing_rates.data.find do |rate|
        rate.percentage == 20.0 &&
          rate.country == "GB" &&
          rate.inclusive == false
      end

      # Stripe has no uniqueness constraint for equivalent tax rates. The cache
      # avoids repeated lookups after the first winner, accepting a small
      # duplicate-create race window during a cold cache.
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
