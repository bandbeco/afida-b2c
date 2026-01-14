# frozen_string_literal: true

class CreateBlogPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :blog_posts do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :body, null: false
      t.text :excerpt
      t.boolean :published, null: false, default: false
      t.datetime :published_at
      t.string :meta_title
      t.text :meta_description

      t.timestamps
    end

    add_index :blog_posts, :slug, unique: true
    add_index :blog_posts, :published_at
    add_index :blog_posts, :published
  end
end
