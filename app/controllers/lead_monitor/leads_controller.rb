module LeadMonitor
  class LeadsController < ActionController::Base
    include Authentication
    layout "lead_monitor"
    before_action :require_admin
    before_action :set_lead, only: %i[show update activity]

    def index
      @classification = params[:classification].presence
      @leads = Lead.includes(:activities).order(created_at: :desc, id: :desc)
      @leads = @leads.where(classification: @classification) if Lead::CLASSIFICATIONS.key?(@classification)
      respond_to do |format|
        format.html do
          @page = [ params[:page].to_i, 1 ].max
          @leads = @leads.limit(50).offset((@page - 1) * 50)
          @runs = Run.order(id: :desc).limit(5)
        end
        format.csv { send_data LeadsCsv.generate(@leads.reorder(nil)), filename: "lead-monitor-#{Date.current}.csv", type: "text/csv" }
      end
    end

    def show
    end

    def update
      attributes = params.require(:lead).permit(:classification, :opening_on, :evidence_kind, :evidence_url,
        :evidence_notes, :location_verified, :contact_name, :contact_email, :contact_phone, :website)
      @lead.assign_attributes(attributes)
      if (@lead.changed & Lead::REVIEW_FIELDS).any?
        @lead.reviewed_by = Current.user.email_address
        @lead.reviewed_at = Time.current
      end
      if @lead.save
        redirect_to lead_monitor_lead_path(@lead), notice: "Review saved."
      else
        render :show, status: :unprocessable_entity
      end
    end

    def activity
      attributes = params.require(:activity).permit(:kind, :notes)
      Outreach.new(@lead).record!(kind: attributes[:kind], notes: attributes[:notes], actor: Current.user.email_address)
      redirect_to lead_monitor_lead_path(@lead), notice: "Contact activity recorded."
    rescue Outreach::NotEligible, ActiveRecord::RecordInvalid => e
      @lead.errors.add(:base, e.message)
      render :show, status: :unprocessable_entity
    end

    private

    def set_lead
      @lead = Lead.find(params[:id])
    end

    def require_admin
      redirect_to root_path, alert: "You are not authorized to access this page." unless Current.user&.admin?
    end
  end
end
