require "csv"

class ReplaceProductDescriptionWithThreeFields < ActiveRecord::Migration[8.1]
  def up
    # Add three new description fields
    add_column :products, :description_short, :text
    add_column :products, :description_standard, :text
    add_column :products, :description_detailed, :text

    # SAFETY: First, copy existing descriptions to description_standard as fallback
    # This preserves data if CSV is missing or has issues
    say "Preserving existing product descriptions..."
    preserved_count = 0
    Product.unscoped.find_each do |product|
      if product.description.present?
        product.update_column(:description_standard, product.description)
        preserved_count += 1
      end
    end
    say "Preserved #{preserved_count} existing product descriptions", true

    # Then populate from CSV (will override preserved data if CSV has matching SKU)
    populate_descriptions_from_csv

    # Remove old description field
    remove_column :products, :description
  end

  def down
    # Add back old description field
    add_column :products, :description, :text

    # Copy description_standard to description as best fallback
    Product.unscoped.find_each do |product|
      product.update_column(:description, product.description_standard)
    end

    # Remove new fields
    remove_column :products, :description_short
    remove_column :products, :description_standard
    remove_column :products, :description_detailed
  end

  private

  def populate_descriptions_from_csv
    csv_path = Rails.root.join("lib", "data", "products.csv")

    unless File.exist?(csv_path)
      say "WARNING: CSV file not found at #{csv_path}", true
      say "Products will use preserved descriptions or remain blank", true
      return
    end

    say "Loading product descriptions from CSV..."

    # Read CSV and build a lookup hash by SKU
    descriptions_by_sku = {}

    begin
      CSV.foreach(csv_path, headers: true, encoding: "UTF-8", liberal_parsing: true) do |row|
        sku = row["sku"]
        next if sku.blank?

        descriptions_by_sku[sku] = {
          short: row["description_short"],
          standard: row["description_standard"],
          detailed: row["description_detailed"]
        }
      end
    rescue CSV::MalformedCSVError => e
      say "WARNING: CSV parsing error: #{e.message}", true
      say "Continuing with parsed data...", true
    end

    # Update products with their descriptions
    updated_count = 0
    Product.unscoped.find_each do |product|
      next if product.sku.blank?

      descriptions = descriptions_by_sku[product.sku]
      next unless descriptions

      product.update_columns(
        description_short: descriptions[:short],
        description_standard: descriptions[:standard],
        description_detailed: descriptions[:detailed]
      )
      updated_count += 1
    end

    say "Updated #{updated_count} products from CSV data", true
  end
end
