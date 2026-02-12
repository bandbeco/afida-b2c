class CreateBrandingImages < ActiveRecord::Migration[8.1]
  def change
    create_table :branding_images do |t|
      t.references :site_setting, null: false, foreign_key: true
      t.string :alt_text, null: false, default: ""
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :branding_images, [ :site_setting_id, :position ]
  end
end
