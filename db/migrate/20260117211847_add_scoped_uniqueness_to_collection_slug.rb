class AddScopedUniquenessToCollectionSlug < ActiveRecord::Migration[8.1]
  def change
    # Remove the global uniqueness constraint on slug
    remove_index :collections, :slug

    # Add scoped uniqueness: slug must be unique within each sample_pack scope
    # This allows /collections/takeaway and /samples/takeaway to coexist
    add_index :collections, [ :slug, :sample_pack ], unique: true
  end
end
