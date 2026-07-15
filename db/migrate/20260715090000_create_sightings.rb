class CreateSightings < ActiveRecord::Migration[8.1]
  def change
    create_table :sightings do |t|
      t.string :source, null: false
      t.string :external_id, null: false

      t.timestamps
    end

    add_index :sightings, [ :source, :external_id ], unique: true
  end
end
