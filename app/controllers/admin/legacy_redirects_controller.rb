# frozen_string_literal: true

class Admin::LegacyRedirectsController < Admin::ApplicationController
  before_action :set_redirect, only: [ :show, :edit, :update, :destroy, :toggle, :test ]

  # T061: Index action
  def index
    @redirects = LegacyRedirect.all

    # Filter by status
    @redirects = case params[:status]
    when "active"
      @redirects.active
    when "inactive"
      @redirects.inactive
    else
      @redirects
    end

    # Sort
    @redirects = case params[:sort]
    when "recent"
      @redirects.recently_updated
    when "alphabetical"
      @redirects.order(:legacy_path)
    else  # Default: most_used
      @redirects.most_used
    end

    # No pagination needed for ~63 redirects
    @redirects = @redirects.to_a
  end

  # T062: Show action
  def show
  end

  # T063: New action
  def new
    @redirect = LegacyRedirect.new
  end

  # T064: Create action
  def create
    @redirect = LegacyRedirect.new(redirect_params)

    if @json_parse_error
      @redirect.errors.add(:variant_params, "invalid JSON format: #{@json_parse_error}")
      render :new, status: :unprocessable_entity
    elsif @redirect.save
      redirect_to admin_legacy_redirect_url(@redirect), notice: "Redirect created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  # T065: Edit action
  def edit
  end

  # T066: Update action
  def update
    if @json_parse_error
      @redirect.errors.add(:variant_params, "invalid JSON format: #{@json_parse_error}")
      render :edit, status: :unprocessable_entity
    elsif @redirect.update(redirect_params)
      redirect_to admin_legacy_redirect_url(@redirect), notice: "Redirect updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # T067: Destroy action
  def destroy
    @redirect.destroy!
    redirect_to admin_legacy_redirects_url, notice: "Redirect deleted successfully"
  end

  # T068: Toggle action
  def toggle
    if @redirect.active?
      @redirect.deactivate!
      redirect_to admin_legacy_redirects_url, notice: "Redirect deactivated"
    else
      @redirect.activate!
      redirect_to admin_legacy_redirects_url, notice: "Redirect activated"
    end
  end

  # T069: Test action
  def test
    @source_url = @redirect.legacy_path
    @target_url = @redirect.target_url
    @http_status = 301
    @variant_match_status = check_variant_match
  end

  private

  def set_redirect
    @redirect = LegacyRedirect.find(params[:id])
  end

  def redirect_params
    permitted = params.require(:legacy_redirect).permit(:legacy_path, :target_slug, :active, :variant_params)

    # Parse variant_params if it's a JSON string
    if permitted[:variant_params].is_a?(String)
      begin
        permitted[:variant_params] = JSON.parse(permitted[:variant_params])
      rescue JSON::ParserError => e
        @json_parse_error = e.message
        permitted[:variant_params] = {}
      end
    end

    permitted
  end

  def check_variant_match
    product = Product.find_by(slug: @redirect.target_slug)
    return "Product not found" unless product

    if @redirect.variant_params.present?
      "Variant parameters: #{@redirect.variant_params.inspect}"
    else
      "No variant parameters"
    end
  end
end
