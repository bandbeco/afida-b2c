require "csv"

class ReplaceProductDescriptionWithThreeFields < ActiveRecord::Migration[8.1]
  def up
    # Add three new description fields
    add_column :products, :description_short, :text
    add_column :products, :description_standard, :text
    add_column :products, :description_detailed, :text

    # Populate from CSV data
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
    return unless File.exist?(csv_path)

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
      Rails.logger.warn "CSV parsing error: #{e.message}. Continuing with parsed data."
    end

    # Update products with their descriptions
    Product.unscoped.find_each do |product|
      next if product.sku.blank?

      descriptions = descriptions_by_sku[product.sku]
      next unless descriptions

      product.update_columns(
        description_short: descriptions[:short],
        description_standard: descriptions[:standard],
        description_detailed: descriptions[:detailed]
      )
    end
  end
end
