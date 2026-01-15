class AddOutrankIdToBlogPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :blog_posts, :outrank_id, :string
    add_index :blog_posts, :outrank_id, unique: true
  end
end
