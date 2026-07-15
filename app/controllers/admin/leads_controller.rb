module Admin
  class LeadsController < Admin::ApplicationController
    # GET /admin/leads
    def index
      leads = Lead.recent_first
      leads = leads.where(status: params[:status]) if Lead.statuses.key?(params[:status])
      @pagy, @leads = pagy(leads)
    end

    # PATCH /admin/leads/:id/update_status
    def update_status
      @lead = Lead.find(params[:id])

      unless Lead.statuses.key?(params[:status])
        return redirect_back fallback_location: admin_leads_path, alert: "Unknown status.", status: :see_other
      end

      @lead.update!(status: params[:status])
      # redirect_back keeps the admin on their current filter/page.
      redirect_back fallback_location: admin_leads_path,
                    notice: "#{@lead.business_name} marked #{params[:status].humanize.downcase}.",
                    status: :see_other
    end
  end
end
