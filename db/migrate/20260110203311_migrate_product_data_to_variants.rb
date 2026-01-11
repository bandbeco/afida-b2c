class MigrateProductDataToVariants < ActiveRecord::Migration[8.1]
  def up
    # Step 1: Copy data from products to their variants
    execute <<-SQL
      UPDATE product_variants
      SET
        category_id = products.category_id,
        product_type = products.product_type,
        description_short = products.description_short,
        description_standard = products.description_standard,
        description_detailed = products.description_detailed,
        meta_title = products.meta_title,
        meta_description = products.meta_description,
        b2b_priority = products.b2b_priority,
        best_seller = products.best_seller,
        featured = products.featured,
        material = products.material,
        colour = products.colour,
        base_sku = products.base_sku,
        short_description = products.short_description,
        vat_rate = products.vat_rate,
        organization_id = products.organization_id,
        parent_product_id = products.parent_product_id
      FROM products
      WHERE product_variants.product_id = products.id
    SQL

    # Step 2: Create ProductFamily for products that have multiple variants
    # We use raw SQL to avoid loading models that may not exist yet
    products_with_multiple_variants = execute(<<-SQL).to_a
      SELECT products.id, products.name, products.slug, products.position
      FROM products
      INNER JOIN product_variants ON product_variants.product_id = products.id
      GROUP BY products.id
      HAVING COUNT(product_variants.id) > 1
    SQL

    products_with_multiple_variants.each do |product|
      # Insert into product_families
      execute <<-SQL
        INSERT INTO product_families (name, slug, sort_order, created_at, updated_at)
        VALUES (
          #{quote(product['name'])},
          #{quote(product['slug'])},
          #{product['position'] || 0},
          NOW(),
          NOW()
        )
      SQL

      # Get the inserted product_family id
      family_id = execute("SELECT currval('product_families_id_seq')").first['currval']

      # Update variants to point to this family
      execute <<-SQL
        UPDATE product_variants
        SET product_family_id = #{family_id}
        WHERE product_id = #{product['id']}
      SQL
    end
  end

  def down
    # Clear the copied data
    execute <<-SQL
      UPDATE product_variants
      SET
        category_id = NULL,
        product_family_id = NULL,
        product_type = 0,
        description_short = NULL,
        description_standard = NULL,
        description_detailed = NULL,
        meta_title = NULL,
        meta_description = NULL,
        b2b_priority = 0,
        best_seller = false,
        featured = false,
        material = NULL,
        colour = NULL,
        base_sku = NULL,
        short_description = NULL,
        vat_rate = NULL,
        organization_id = NULL,
        parent_product_id = NULL
    SQL

    # Delete all product families
    execute "DELETE FROM product_families"
  end
end
