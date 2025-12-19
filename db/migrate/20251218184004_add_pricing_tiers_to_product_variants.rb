class AddPricingTiersToProductVariants < ActiveRecord::Migration[8.1]
  def change
    add_column :product_variants, :pricing_tiers, :jsonb
  end
end
