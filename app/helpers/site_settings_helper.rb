module SiteSettingsHelper
  def site_settings
    @_site_settings ||= SiteSetting.instance
  end

  def hero_image_tag(**options)
    if site_settings.hero_image.attached?
      image_tag site_settings.hero_image, **options
    else
      vite_image_tag "images/hero/hero.webp", **options
    end
  end

  def hero_background_color
    site_settings.hero_background_color
  end

  def hero_image_url
    if site_settings.hero_image.attached?
      url_for(site_settings.hero_image)
    else
      vite_asset_url("images/hero/hero.webp")
    end
  end

  def branding_collage_images
    images = site_settings.collage_images.joins(:image_attachment)
    images.any? ? images.with_attached_image : nil
  end

  def branding_gallery_images
    images = site_settings.branding_images.joins(:image_attachment)
    images.any? ? images.with_attached_image : nil
  end
end
