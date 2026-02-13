class AddHeroTextToSiteSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :site_settings, :hero_title_line1, :string
    add_column :site_settings, :hero_title_line2, :string
    add_column :site_settings, :hero_subtitle, :text
  end
end
