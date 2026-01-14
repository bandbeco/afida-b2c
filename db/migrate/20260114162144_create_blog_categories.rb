# frozen_string_literal: true

class CreateBlogCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :blog_categories do |t|
      t.string :name, null: false
      t.string :slug, null: false

      t.timestamps
    end

    add_index :blog_categories, :slug, unique: true

    # Add foreign key to blog_posts
    add_reference :blog_posts, :blog_category, foreign_key: true
  end
end
