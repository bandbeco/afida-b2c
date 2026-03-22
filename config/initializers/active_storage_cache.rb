# frozen_string_literal: true

# Add cache-control headers to Active Storage proxy responses.
# Variants are deterministic (same params produce the same output),
# so they are safe to cache aggressively.
Rails.application.config.after_initialize do
  ActiveStorage::Blobs::ProxyController.before_action do
    response.set_header("Cache-Control", "public, max-age=#{1.year.to_i}, immutable")
  end

  ActiveStorage::Representations::ProxyController.before_action do
    response.set_header("Cache-Control", "public, max-age=#{1.year.to_i}, immutable")
  end
end
