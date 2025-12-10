# frozen_string_literal: true

# Google Tag Manager configuration for GA4 e-commerce tracking
#
# Set GTM_CONTAINER_ID environment variable with your GTM container ID
# Format: GTM-XXXXXXX
#
# In production, set this in your hosting environment:
#   heroku config:set GTM_CONTAINER_ID=GTM-XXXXXXX
#
# In development, you can optionally test with your container by adding
# to .env or exporting the variable

Rails.application.config.x.gtm_container_id = "GTM-NCN4DWXN"
