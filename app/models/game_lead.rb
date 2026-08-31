# An email address The Afida Stack game captured — the bridge from plays to
# pipeline. One row per address: a later capture keeps the first source and
# can only ever upgrade marketing consent, never withdraw it silently.
class GameLead < ApplicationRecord
  SOURCES = %w[win board].freeze

  normalizes :email, with: ->(e) { e.to_s.strip.downcase }

  validates :email, presence: true, uniqueness: { case_sensitive: false },
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :source, inclusion: { in: SOURCES }

  def self.capture(email:, source:, marketing_opt_in: false)
    lead = find_or_initialize_by(email: normalize_value_for(:email, email))
    lead.source ||= source
    lead.marketing_opt_in ||= marketing_opt_in
    lead.save
    lead
  end
end
