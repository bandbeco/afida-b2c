class GamePrizeBudget < ApplicationRecord
  CAP = 200

  def self.available?(kind = "win")
    where(kind: kind, month: Date.current.beginning_of_month).pick(:reserved).to_i < CAP
  end
end
