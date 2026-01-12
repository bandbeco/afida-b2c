# frozen_string_literal: true

class ChangeSampleEligibleDefaultToTrue < ActiveRecord::Migration[8.1]
  def change
    change_column_default :products, :sample_eligible, from: false, to: true
  end
end
