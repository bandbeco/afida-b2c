module LeadMonitor
  class Sighting < Record
    validates :source, :external_id, presence: true
  end
end
