module LeadMonitor
  class Lead < Record
    CLASSIFICATIONS = { "possible" => "Possible new opening", "upcoming" => "Opening soon",
      "recent" => "Confirmed recent opening", "existing" => "Existing business / ownership change" }.freeze
    EVIDENCE_KINDS = %w[business_announcement local_reporting direct_confirmation].freeze
    REVIEW_FIELDS = %w[classification opening_on evidence_kind evidence_url evidence_notes location_verified reviewed_by reviewed_at].freeze

    belongs_to :run, class_name: "LeadMonitor::Run", optional: true
    has_many :activities, class_name: "LeadMonitor::Activity", dependent: :restrict_with_exception

    normalizes :evidence_kind, :evidence_url, :evidence_notes, with: ->(value) { value.presence }

    validates :source, :external_id, :business_name, presence: true
    validates :external_id, uniqueness: { scope: :source }
    validates :classification, inclusion: { in: CLASSIFICATIONS.keys }
    validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
    validate :safe_urls
    validate :qualification_evidence, if: :review_changed?
    validate :opening_window, if: :opening_changed?

    def opening_eligible?(on: Date.current)
      verified_evidence? && opening_in_window?(on)
    end

    def outreach_status
      kinds = activities.map(&:kind)
      return "suppressed" if kinds.include?("suppressed")
      return "replied" if kinds.include?("replied")
      return "contacted" if kinds.include?("sent")

      "not_contacted"
    end

    def next_follow_up_on
      return unless outreach_status == "contacted" && opening_eligible?

      initial = activities.find { |activity| activity.kind == "sent" }
      offset = [ 1, 2, 7 ][activities.count { |activity| activity.kind == "follow_up" }]
      return unless offset

      last_contact = activities.select { |activity| %w[sent follow_up].include?(activity.kind) }.map(&:created_at).max
      [ initial.created_at.to_date + offset, last_contact.to_date + 1 ].max
    end

    private

    def review_changed?
      new_record? || (changed & REVIEW_FIELDS).any?
    end

    def opening_changed?
      new_record? || will_save_change_to_classification? || will_save_change_to_opening_on?
    end

    def verified_evidence?
      EVIDENCE_KINDS.include?(evidence_kind) && location_verified? && reviewed_by.present? &&
        reviewed_at.present? && reviewed_at <= Time.current &&
        (evidence_kind == "direct_confirmation" ? evidence_notes.present? : http_url?(evidence_url))
    end

    def opening_in_window?(on)
      return false unless opening_on

      case classification
      when "upcoming" then opening_on > on
      when "recent" then opening_on.between?(on - 60, on)
      else false
      end
    end

    def qualification_evidence
      return unless %w[upcoming recent].include?(classification)

      errors.add(:base, "Verify opening evidence, location, reviewer and date checked") unless verified_evidence?
    end

    def opening_window
      return unless %w[upcoming recent].include?(classification)

      errors.add(:opening_on, "must match the selected opening classification") unless opening_in_window?(Date.current)
    end

    def safe_urls
      %i[evidence_url website].each do |field|
        errors.add(field, "must be an HTTP or HTTPS URL") if self[field].present? && !http_url?(self[field])
      end
    end

    def http_url?(value)
      uri = URI.parse(value.to_s)
      uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?
    rescue URI::InvalidURIError
      false
    end
  end
end
