module LeadMonitor
  # Manual contact log only. Never sends prospect messages or touches customer data.
  class Outreach
    NotEligible = Class.new(StandardError)

    def initialize(lead)
      @lead = lead
    end

    def record!(kind:, actor:, notes:)
      @lead.with_lock do
        @lead.activities.reset
        if %w[sent follow_up].include?(kind) && !allowed?(kind)
          raise NotEligible, "Verify current opening eligibility, contact details and follow-up timing before contact"
        end
        @lead.activities.create!(kind: kind, actor: actor, notes: notes)
      end
    end

    def allowed?(kind)
      return false unless @lead.opening_eligible? && (@lead.contact_email.present? || @lead.contact_phone.present?)

      case kind
      when "sent" then @lead.outreach_status == "not_contacted"
      when "follow_up" then @lead.next_follow_up_on.present? && @lead.next_follow_up_on <= Date.current
      else false
      end
    end

    def template
      return unless @lead.opening_eligible? && !%w[replied suppressed].include?(@lead.outreach_status)

      if @lead.outreach_status == "contacted"
        "Hi #{@lead.contact_name.presence || @lead.business_name}, just following up on the free Café Packaging Starter Kit for #{@lead.business_name}. Would a sample box and help choosing quantities be useful?"
      else
        "Hi #{@lead.contact_name.presence || @lead.business_name}, we'd love to offer #{@lead.business_name} a free Café Packaging Starter Kit to help with your opening. Would a sample box and help choosing the right packaging quantities be useful?"
      end
    end
  end
end
