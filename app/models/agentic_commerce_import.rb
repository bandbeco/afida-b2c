# One catalogue feed push to Stripe Agentic Commerce Suite (a
# ProductCatalogImport on Stripe's side). Records what was sent so the next
# product push can diff SKUs for deletions and so ops can see why an import
# failed. See docs/plans/2026-09-02-stripe-agentic-commerce.md.
class AgenticCommerceImport < ApplicationRecord
  FEED_TYPES = %w[product inventory pricing promotion].freeze
  MODES = %w[upsert replace].freeze
  # awaiting_upload and processing are Stripe's own states; upload_failed is
  # ours, for a CSV that never reached the presigned URL.
  STATUSES = %w[awaiting_upload upload_failed processing succeeded succeeded_with_errors failed].freeze

  validates :stripe_import_id, presence: true, uniqueness: true
  validates :feed_type, inclusion: { in: FEED_TYPES }
  validates :mode, inclusion: { in: MODES }
  validates :status, inclusion: { in: STATUSES }

  scope :for_feed, ->(feed_type) { where(feed_type: feed_type) }
  scope :succeeded, -> { where(status: %w[succeeded succeeded_with_errors]) }
end
