module LeadMonitor
  class Source < Record
    validates :name, presence: true
  end
end
