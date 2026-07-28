# Whether checkout renders on afida.com (Stripe custom UI) instead of
# redirecting to Stripe's hosted page. Read from ENV on every call, not into a
# constant, so flipping back to hosted is an env change + redeploy with no code
# edit — the rollback lever the on-site checkout spec promises.
class OnsiteCheckout
  TRUTHY = %w[true 1].freeze

  def self.enabled?
    TRUTHY.include?(ENV["ONSITE_CHECKOUT"].to_s.strip.downcase)
  end
end
