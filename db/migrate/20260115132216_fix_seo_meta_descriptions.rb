class FixSeoMetaDescriptions < ActiveRecord::Migration[8.1]
  def up
    # Fix cups-and-lids meta description (was 161 chars, now 144)
    execute <<-SQL
      UPDATE categories
      SET meta_description = 'Disposable paper coffee cups and lids for cafes and takeaway. Single wall, double wall and ripple cups in all sizes. Free UK delivery over £100.'
      WHERE slug = 'cups-and-lids'
    SQL

    # Fix takeaway-extras title (was 63 chars, now 51)
    execute <<-SQL
      UPDATE categories
      SET meta_title = 'Takeaway Accessories | Paper Bags & Cutlery | Afida'
      WHERE slug = 'takeaway-extras'
    SQL

    # Add meta description to branded double-wall-coffee-cups product (was 83 chars from fallback, now 147)
    execute <<-SQL
      UPDATE products
      SET meta_description = 'Custom branded double wall coffee cups with your logo. Premium insulated cups that keep drinks hotter. Minimum order 1,000 units. Free UK delivery.'
      WHERE slug = 'double-wall-coffee-cups'
    SQL
  end

  def down
    # Revert cups-and-lids meta description
    execute <<-SQL
      UPDATE categories
      SET meta_description = 'Disposable paper coffee cups and lids for cafes and takeaway. Single wall double wall and ripple cups in all sizes. Bulk pricing with free UK delivery over £100.'
      WHERE slug = 'cups-and-lids'
    SQL

    # Revert takeaway-extras title
    execute <<-SQL
      UPDATE categories
      SET meta_title = 'Takeaway Accessories | Paper Bags Wooden Cutlery & Cup Carriers'
      WHERE slug = 'takeaway-extras'
    SQL

    # Remove meta description from branded product (will fall back to description_standard)
    execute <<-SQL
      UPDATE products
      SET meta_description = NULL
      WHERE slug = 'double-wall-coffee-cups'
    SQL
  end
end
