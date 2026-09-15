class CreateLeadMonitor < ActiveRecord::Migration[8.1]
  def change
    create_table :lead_monitor_sources do |t|
      t.string :name, null: false
      t.datetime :seeded_at
      t.timestamps
    end
    add_index :lead_monitor_sources, :name, unique: true

    create_table :lead_monitor_runs do |t|
      t.string :source, null: false
      t.string :status, null: false
      t.integer :fetched_count, null: false, default: 0
      t.integer :new_count, null: false, default: 0
      t.string :error
      t.datetime :notified_at
      t.timestamps
    end
    add_index :lead_monitor_runs, :notified_at

    create_table :lead_monitor_sightings do |t|
      t.string :source, null: false
      t.string :external_id, null: false
      t.datetime :created_at, null: false
    end
    add_index :lead_monitor_sightings, [ :source, :external_id ], unique: true

    create_table :lead_monitor_leads do |t|
      t.references :run, foreign_key: { to_table: :lead_monitor_runs }
      t.string :source, null: false
      t.string :external_id, null: false
      t.string :business_name, null: false
      t.string :business_type
      t.text :address
      t.string :postcode
      t.string :local_authority
      t.jsonb :payload, null: false, default: {}
      t.string :classification, null: false, default: "possible"
      t.date :opening_on
      t.string :evidence_kind
      t.text :evidence_url
      t.text :evidence_notes
      t.boolean :location_verified, null: false, default: false
      t.string :reviewed_by
      t.datetime :reviewed_at
      t.string :contact_name
      t.string :contact_email
      t.string :contact_phone
      t.text :website
      t.timestamps
    end
    add_index :lead_monitor_leads, [ :source, :external_id ], unique: true
    add_index :lead_monitor_leads, [ :classification, :created_at ]

    create_table :lead_monitor_activities do |t|
      t.references :lead, null: false, foreign_key: { to_table: :lead_monitor_leads }
      t.string :kind, null: false
      t.string :actor, null: false
      t.text :notes, null: false
      t.datetime :created_at, null: false
    end
  end
end
