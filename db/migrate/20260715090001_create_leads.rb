class CreateLeads < ActiveRecord::Migration[8.1]
  def change
    create_table :leads do |t|
      t.string :source, null: false
      t.string :external_id, null: false
      t.string :business_name, null: false
      t.string :business_type
      t.text :address
      t.string :postcode
      t.string :local_authority
      t.string :status, null: false, default: "new_lead"
      t.jsonb :payload, default: {}, null: false

      t.timestamps
    end

    add_index :leads, [ :source, :external_id ], unique: true
    add_index :leads, :status
    add_index :leads, :created_at
  end
end
