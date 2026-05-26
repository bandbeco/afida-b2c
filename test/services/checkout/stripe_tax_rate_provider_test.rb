require "test_helper"

class Checkout::StripeTaxRateProviderTest < ActiveSupport::TestCase
  include StripeTestHelper

  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.delete(Checkout::StripeTaxRateProvider::UK_VAT_RATE_ID_CACHE_KEY)
  end

  teardown do
    Rails.cache.delete(Checkout::StripeTaxRateProvider::UK_VAT_RATE_ID_CACHE_KEY)
    Rails.cache = @original_cache
  end

  test "returns an existing active exclusive UK VAT tax rate" do
    existing_tax_rate = build_stripe_tax_rate(id: "txr_existing")
    Stripe::TaxRate.expects(:list).with(active: true, limit: 100).returns(build_stripe_list([ existing_tax_rate ]))
    Stripe::TaxRate.expects(:create).never

    assert_equal existing_tax_rate, Checkout::StripeTaxRateProvider.new.tax_rate
    assert_equal "txr_existing", Rails.cache.read(Checkout::StripeTaxRateProvider::UK_VAT_RATE_ID_CACHE_KEY)
  end

  test "creates UK VAT tax rate when none exists" do
    created_tax_rate = build_stripe_tax_rate(id: "txr_created")
    Stripe::TaxRate.expects(:list).with(active: true, limit: 100).returns(build_stripe_list([]))
    Stripe::TaxRate.expects(:create).with({
      display_name: "VAT",
      percentage: 20,
      country: "GB",
      jurisdiction: "United Kingdom",
      description: "Value Added Tax",
      inclusive: false
    }).returns(created_tax_rate)

    assert_equal created_tax_rate, Checkout::StripeTaxRateProvider.new.tax_rate
    assert_equal "txr_created", Rails.cache.read(Checkout::StripeTaxRateProvider::UK_VAT_RATE_ID_CACHE_KEY)
  end

  test "uses cached tax rate id without listing tax rates" do
    Rails.cache.write(Checkout::StripeTaxRateProvider::UK_VAT_RATE_ID_CACHE_KEY, "txr_cached")
    Stripe::TaxRate.expects(:list).never
    Stripe::TaxRate.expects(:create).never

    assert_equal "txr_cached", Checkout::StripeTaxRateProvider.new.tax_rate.id
  end

  test "memoizes tax rate for one provider instance" do
    existing_tax_rate = build_stripe_tax_rate(id: "txr_existing")
    provider = Checkout::StripeTaxRateProvider.new
    Stripe::TaxRate.expects(:list).once.returns(build_stripe_list([ existing_tax_rate ]))

    assert_equal existing_tax_rate, provider.tax_rate
    assert_equal existing_tax_rate, provider.tax_rate
  end
end
