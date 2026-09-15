module LeadMonitor
  class Run < Record
    has_many :leads, class_name: "LeadMonitor::Lead", dependent: :restrict_with_exception
    validates :source, presence: true
    validates :status, inclusion: { in: %w[seeded completed failed] }
    scope :pending_notification, -> { where(notified_at: nil).order(:id) }
  end
end
