# frozen_string_literal: true

class OauthApplication < ApplicationRecord
  has_secure_password :client_secret

  validates :client_id, presence: true, uniqueness: true
  validates :name, presence: true
end
