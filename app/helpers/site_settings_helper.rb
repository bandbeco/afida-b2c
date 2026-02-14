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

  def hero_title_line1
    site_settings.hero_title_line1.presence || "Quality Packaging Supplies."
  end

  def hero_title_line2
    site_settings.hero_title_line2.presence || "Delivered Fast."
  end

  def hero_subtitle
    site_settings.hero_subtitle.presence || "Supply your restaurant, café, or takeaway with high-quality packaging. From custom branded cups to bamboo pulp straws, we deliver everything you need within 48 hours."
  end

  def hero_image_url
    if site_settings.hero_image.attached?
      polymorphic_url(site_settings.hero_image)
    else
      vite_asset_url("images/hero/hero.webp")
    end
  end

  def branding_collage_images
    images = site_settings.collage_images.joins(:image_attachment).with_attached_image.load
    images.any? ? images : nil
  end

  def branding_gallery_images
    images = site_settings.branding_images.joins(:image_attachment).with_attached_image.load
    images.any? ? images : nil
  end
end
