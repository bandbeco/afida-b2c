class PopulateProductVariantSlugs < ActiveRecord::Migration[8.1]
  def up
    ProductVariant.includes(:product).find_each do |variant|
      # Skip orphaned variants (product was deleted)
      next if variant.product.nil?

      base = "#{variant.name} #{variant.product.name}".parameterize
      slug = base
      counter = 2

      # Handle duplicates with counter suffix
      while ProductVariant.where.not(id: variant.id).exists?(slug: slug)
        slug = "#{base}-#{counter}"
        counter += 1
      end

      variant.update_column(:slug, slug)
    end

    # Handle orphaned variants with fallback slug
    ProductVariant.where(slug: nil).find_each do |variant|
      base = "variant-#{variant.sku}".parameterize
      slug = base
      counter = 2
      while ProductVariant.where.not(id: variant.id).exists?(slug: slug)
        slug = "#{base}-#{counter}"
        counter += 1
      end
      variant.update_column(:slug, slug)
    end

    # Now enforce NOT NULL after all slugs are populated
    change_column_null :product_variants, :slug, false
  end

  def down
    change_column_null :product_variants, :slug, true
  end
end
