class AddCertificationsToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :certifications, :string
  end
end
