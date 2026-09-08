class CreateOauthApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_applications do |t|
      t.string :client_id, null: false
      t.string :client_secret_digest, null: false
      t.string :name, null: false

      t.timestamps
    end
    add_index :oauth_applications, :client_id, unique: true
  end
end
