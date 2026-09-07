class GameEvent < ApplicationRecord
  belongs_to :game_participant, optional: true
  belongs_to :order, optional: true

  def self.record(name, participant: nil, key: SecureRandom.uuid, order: nil, **properties)
    create_or_find_by!(event_key: key) do |event|
      event.name = name
      event.game_participant = participant
      event.order = order
      event.properties = properties.merge(experiment: participant&.experiment).compact
    end
  end
end
