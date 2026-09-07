class GameCrown < ApplicationRecord
  belongs_to :leaderboard_entry, optional: true
  scope :published, -> { where.not(published_at: nil, publication_url: nil).order(month: :desc) }
  validates :publication_url, format: { with: %r{\Ahttps://(?:www\.)?instagram\.com/} }, allow_blank: true
end
