module LeadMonitor
  class Activity < Record
    KINDS = %w[sent follow_up replied suppressed].freeze
    belongs_to :lead, class_name: "LeadMonitor::Lead"
    validates :kind, inclusion: { in: KINDS }
    validates :actor, :notes, presence: true
  end
end
