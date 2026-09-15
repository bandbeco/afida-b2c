module LeadMonitor
  class Run < Record
    DIGEST_CLAIM_TIMEOUT = 10.minutes

    has_many :leads, class_name: "LeadMonitor::Lead", dependent: :restrict_with_exception
    validates :source, presence: true
    validates :status, inclusion: { in: %w[seeded completed failed] }
    scope :pending_notification, -> { where(notified_at: nil) }
    scope :digest_claimable, -> {
      pending_notification.where(digest_claimed_at: nil).or(pending_notification.where(digest_claimed_at: ...DIGEST_CLAIM_TIMEOUT.ago))
    }

    def claim_digest!
      self.class.digest_claimable.where(id: id).update_all(digest_claimed_at: Time.current) == 1
    end

    def release_digest_claim!
      self.class.where(id: id).update_all(digest_claimed_at: nil)
    end
  end
end
