class RemoveUnusedSearchVectorFromProductVariants < ActiveRecord::Migration[8.1]
  def up
    execute <<-SQL
      DROP TRIGGER IF EXISTS product_variants_search_update ON product_variants;
      DROP FUNCTION IF EXISTS product_variants_search_trigger();
    SQL

    remove_column :product_variants, :search_vector
  end

  def down
    add_column :product_variants, :search_vector, :tsvector
    add_index :product_variants, :search_vector, using: :gin

    execute <<-SQL
      CREATE OR REPLACE FUNCTION product_variants_search_trigger() RETURNS trigger AS $$
      BEGIN
        NEW.search_vector :=
          setweight(to_tsvector('english', coalesce(NEW.name, '')), 'A') ||
          setweight(to_tsvector('english', coalesce(NEW.sku, '')), 'B');
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER product_variants_search_update
      BEFORE INSERT OR UPDATE ON product_variants
      FOR EACH ROW EXECUTE FUNCTION product_variants_search_trigger();
    SQL

    # Backfill existing records
    ProductVariant.find_each(&:touch)
  end
end
