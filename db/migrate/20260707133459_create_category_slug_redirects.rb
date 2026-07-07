class CreateCategorySlugRedirects < ActiveRecord::Migration[8.1]
  def change
    create_table :category_slug_redirects do |t|
      t.string :old_slug, null: false
      t.references :category, null: false, foreign_key: true

      t.timestamps
    end
    add_index :category_slug_redirects, :old_slug, unique: true
  end
end
