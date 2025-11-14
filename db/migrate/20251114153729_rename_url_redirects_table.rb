class RenameUrlRedirectsTable < ActiveRecord::Migration[8.1]
  def change
    rename_table :legacy_redirects, :url_redirects
  end
end
