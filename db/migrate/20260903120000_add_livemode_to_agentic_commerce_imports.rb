class AddLivemodeToAgenticCommerceImports < ActiveRecord::Migration[8.1]
  def change
    add_column :agentic_commerce_imports, :livemode, :boolean
  end
end
