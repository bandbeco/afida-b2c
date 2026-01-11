module Organizations
  class ProductsController < ApplicationController
    before_action :require_organization_membership

    def index
      @products = Current.user.organization
                              .customized_products
                              .with_attached_product_photo
                              .order(created_at: :desc)
    end

    def show
      @product = Current.user.organization
                             .customized_products
                             .find_by!(slug: params[:id])
    end

    private

    def require_organization_membership
      unless Current.user&.organization_id.present?
        redirect_to root_path, alert: "You must be a member of an organization to access this page"
      end
    end
  end
end
