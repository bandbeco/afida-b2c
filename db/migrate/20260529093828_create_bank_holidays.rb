class CreateBankHolidays < ActiveRecord::Migration[8.1]
  def change
    create_table :bank_holidays do |t|
      t.string :division, null: false, default: "england-and-wales"
      t.date :date, null: false
      t.string :title

      t.timestamps
    end

    add_index :bank_holidays, [ :division, :date ], unique: true
  end
end
