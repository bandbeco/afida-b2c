# Whether checkout renders on afida.com (Stripe custom UI) instead of
# redirecting to Stripe's hosted page. Two levers:
#
# - The ONSITE_CHECKOUT env var, the global switch. Read from ENV on every
#   call, not into a constant, so flipping back to hosted is an env change +
#   redeploy with no code edit: the rollback lever the on-site checkout spec
#   promises.
# - A per-session preview flag, so the mode can be tested in production before
#   the global switch is thrown: any URL with ?onsite_checkout=1 turns it on
#   for that browser session, ?onsite_checkout=0 back off (captured by
#   ApplicationController#capture_onsite_checkout_preview).
class OnsiteCheckout
  TRUTHY = %w[true 1].freeze
  PREVIEW_SESSION_KEY = "onsite_checkout_preview"

  def self.enabled?(session = nil)
    truthy?(ENV["ONSITE_CHECKOUT"]) || preview?(session)
  end

  def self.preview?(session)
    session ? session[PREVIEW_SESSION_KEY].present? : false
  end

  def self.truthy?(value)
    TRUTHY.include?(value.to_s.strip.downcase)
  end
end
