class RenameUrlRedirectsLegacyPathToSourcePath < ActiveRecord::Migration[8.1]
  def change
    rename_column :url_redirects, :legacy_path, :source_path
  end
end
