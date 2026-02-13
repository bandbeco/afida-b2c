class CreateSiteSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :site_settings do |t|
      t.string :hero_background_color, null: false, default: "#ffffff"

      t.timestamps
    end
  end
end
