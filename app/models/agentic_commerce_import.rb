class AgenticCommerceImport < ApplicationRecord
  FEED_TYPES = %w[product inventory pricing promotion].freeze
  MODES = %w[upsert replace].freeze
  STATUSES = %w[awaiting_upload upload_failed processing succeeded succeeded_with_errors failed].freeze

  validates :stripe_import_id, presence: true, uniqueness: true
  validates :feed_type, inclusion: { in: FEED_TYPES }
  validates :mode, inclusion: { in: MODES }
  validates :status, inclusion: { in: STATUSES }

  scope :for_feed, ->(feed_type) { where(feed_type: feed_type) }
  scope :succeeded, -> { where(status: %w[succeeded succeeded_with_errors]) }
end
