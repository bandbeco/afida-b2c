class GameParticipant < ApplicationRecord
  has_many :leaderboard_entries
  has_many :game_awards
  normalizes :email, with: ->(value) { value.to_s.strip.downcase.presence }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  before_validation(on: :create) { self.ref_code ||= SecureRandom.hex(12) }

  def share_url
    Rails.application.routes.url_helpers.game_url(
      host: Rails.application.config.action_mailer.default_url_options.fetch(:host), ref: ref_code)
  end

  def attach_email!(address)
    update!(email: address)
    GameLead.where(inviter: self, referrer_rewarded_at: nil).find_each do |lead|
      order = lead.qualifying_order || lead.first_purchase
      GameMateCodeJob.perform_later(order.id) if order
    end
  end
end
