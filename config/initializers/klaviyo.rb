# frozen_string_literal: true

# Klaviyo onsite (klaviyo.js) configuration.
#
# The company_id is a PUBLIC site identifier (it ships in the browser), distinct
# from the private API key in credentials used by KlaviyoService for server-side
# events. klaviyo.js powers onsite forms (popups) and anonymous visitor tracking.
#
# Gated to production so the snippet (and visitor tracking) does not load in
# development or test, mirroring the GTM container configuration.

Rails.application.config.x.klaviyo_company_id = if Rails.env.production?
  "Vxv9um"
end
