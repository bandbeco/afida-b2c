module AdminAuthorization
  extend ActiveSupport::Concern

  included do
    before_action :require_admin
  end

  private

  def require_admin
    redirect_to root_path, alert: "You are not authorized to access this page." unless Current.user&.admin?
  end
end
