class Admin::SettingsController < Admin::ApplicationController
  before_action :set_site_setting

  def show
    @branding_images = @site_setting.branding_images.with_attached_image
  end

  def update
    if @site_setting.update(site_setting_params)
      redirect_to admin_settings_path, notice: "Settings updated successfully."
    else
      @branding_images = @site_setting.branding_images.with_attached_image
      render :show, status: :unprocessable_entity
    end
  end

  def destroy_hero_image
    if @site_setting.hero_image.attached?
      @site_setting.hero_image.purge
      redirect_to admin_settings_path, notice: "Hero image removed."
    else
      redirect_to admin_settings_path, alert: "No hero image to remove."
    end
  end

  def add_branding_image
    @branding_image = @site_setting.branding_images.build(branding_image_params)
    if @branding_image.save
      redirect_to admin_settings_path, notice: "Branding image added."
    else
      redirect_to admin_settings_path, alert: @branding_image.errors.full_messages.to_sentence
    end
  end

  def remove_branding_image
    @branding_image = @site_setting.branding_images.find(params[:id])
    @branding_image.destroy
    redirect_to admin_settings_path, notice: "Branding image removed."
  end

  def move_branding_image_higher
    @branding_image = @site_setting.branding_images.find(params[:id])
    @branding_image.move_higher
    redirect_to admin_settings_path
  end

  def move_branding_image_lower
    @branding_image = @site_setting.branding_images.find(params[:id])
    @branding_image.move_lower
    redirect_to admin_settings_path
  end

  def update_branding_image
    @branding_image = @site_setting.branding_images.find(params[:id])
    if @branding_image.update(branding_image_params)
      redirect_to admin_settings_path, notice: "Branding image updated."
    else
      redirect_to admin_settings_path, alert: @branding_image.errors.full_messages.to_sentence
    end
  end

  private

  def set_site_setting
    @site_setting = SiteSetting.instance
  end

  def site_setting_params
    params.require(:site_setting).permit(:hero_background_color, :hero_image)
  end

  def branding_image_params
    params.require(:branding_image).permit(:image, :alt_text)
  end
end
