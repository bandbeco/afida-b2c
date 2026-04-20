# frozen_string_literal: true

require "test_helper"
require "rake"
require "csv"

class ImportSpecsTaskTest < ActiveSupport::TestCase
  setup do
    Shop::Application.load_tasks unless Rake::Task.task_defined?("products:import_specs")
  end

  teardown do
    Rake::Task["products:import_specs"].reenable
  end

  test "updates product dimensions from CSV" do
    product = products(:one)
    csv_path = write_csv([
      { afida_sku: product.sku, product_length: "200mm", product_width: "150mm", product_height: "100mm" }
    ])

    Rake::Task["products:import_specs"].invoke(csv_path)
    product.reload

    assert_equal 200, product.length_in_mm
    assert_equal 150, product.width_in_mm
    assert_equal 100, product.height_in_mm
  end

  test "converts inches to mm" do
    product = products(:one)
    csv_path = write_csv([
      { afida_sku: product.sku, product_length: "10 inches", product_width: "7 in", product_height: "12 inches" }
    ])

    Rake::Task["products:import_specs"].invoke(csv_path)
    product.reload

    assert_equal 254, product.length_in_mm
    assert_equal 178, product.width_in_mm
    assert_equal 305, product.height_in_mm
  end

  test "converts cm to mm" do
    product = products(:one)
    csv_path = write_csv([
      { afida_sku: product.sku, product_length: "26 cm", product_width: "14 cm" }
    ])

    Rake::Task["products:import_specs"].invoke(csv_path)
    product.reload

    assert_equal 260, product.length_in_mm
    assert_equal 140, product.width_in_mm
  end

  test "updates weight in grams" do
    product = products(:one)
    csv_path = write_csv([
      { afida_sku: product.sku, product_weight: "18.2g" }
    ])

    Rake::Task["products:import_specs"].invoke(csv_path)
    product.reload

    assert_equal 18, product.weight_in_g
  end

  test "converts kg weight to grams" do
    product = products(:one)
    csv_path = write_csv([
      { afida_sku: product.sku, product_weight: "9 kg" }
    ])

    Rake::Task["products:import_specs"].invoke(csv_path)
    product.reload

    assert_equal 9000, product.weight_in_g
  end

  test "converts lbs weight to grams" do
    product = products(:one)
    csv_path = write_csv([
      { afida_sku: product.sku, product_weight: "Approx. 0.7 lbs" }
    ])

    Rake::Task["products:import_specs"].invoke(csv_path)
    product.reload

    assert_equal 318, product.weight_in_g
  end

  test "updates certifications" do
    product = products(:one)
    csv_path = write_csv([
      { afida_sku: product.sku, certifications: "Compostable, Recyclable" }
    ])

    Rake::Task["products:import_specs"].invoke(csv_path)
    product.reload

    assert_equal "Compostable, Recyclable", product.certifications
  end

  test "updates case dimensions" do
    product = products(:one)
    csv_path = write_csv([
      { afida_sku: product.sku, case_length: "250mm", case_width: "260mm", case_depth: "170mm", case_weight: "9 kg" }
    ])

    Rake::Task["products:import_specs"].invoke(csv_path)
    product.reload

    assert_equal 250, product.case_length_in_mm
    assert_equal 260, product.case_width_in_mm
    assert_equal 170, product.case_depth_in_mm
    assert_equal 9000, product.case_weight_in_g
  end

  test "skips null-like values" do
    product = products(:one)
    product.update_columns(length_in_mm: 999)

    csv_path = write_csv([
      { afida_sku: product.sku, product_length: "Not specified", product_width: "N/A", product_height: "unknown" }
    ])

    Rake::Task["products:import_specs"].invoke(csv_path)
    product.reload

    assert_equal 999, product.length_in_mm
    assert_nil product.width_in_mm
    assert_nil product.height_in_mm
  end

  test "skips unknown SKUs and logs warning" do
    csv_path = write_csv([
      { afida_sku: "NONEXISTENT-SKU", product_length: "200mm" }
    ])

    output = capture_io { Rake::Task["products:import_specs"].invoke(csv_path) }.join

    assert_match(/NONEXISTENT-SKU/, output)
    assert_match(/not found/i, output)
  end

  test "skips unparseable dimension values" do
    product = products(:one)
    csv_path = write_csv([
      { afida_sku: product.sku, product_length: "85mm (top); 55mm (base)", product_width: "200mm" }
    ])

    output = capture_io { Rake::Task["products:import_specs"].invoke(csv_path) }.join
    product.reload

    assert_nil product.length_in_mm
    assert_equal 200, product.width_in_mm
  end

  test "does not update name, size, price, or pac_size" do
    product = products(:one)
    original_name = product.name
    original_price = product.price
    original_pac_size = product.pac_size

    csv_path = write_csv([
      { afida_sku: product.sku, product_length: "200mm" }
    ])

    Rake::Task["products:import_specs"].invoke(csv_path)
    product.reload

    assert_equal original_name, product.name
    assert_equal original_price, product.price
    assert_equal original_pac_size, product.pac_size
  end

  test "handles case dimensions in inches" do
    product = products(:one)
    csv_path = write_csv([
      { afida_sku: product.sku, case_length: "11 inches", case_width: "12 inches" }
    ])

    Rake::Task["products:import_specs"].invoke(csv_path)
    product.reload

    assert_equal 279, product.case_length_in_mm
    assert_equal 305, product.case_width_in_mm
  end

  test "normalises Recyclable / Compostable to comma-separated" do
    product = products(:one)
    csv_path = write_csv([
      { afida_sku: product.sku, certifications: "Recyclable / Compostable" }
    ])

    Rake::Task["products:import_specs"].invoke(csv_path)
    product.reload

    assert_equal "Recyclable, Compostable", product.certifications
  end

  test "updates product depth and diameter" do
    product = products(:one)
    csv_path = write_csv([
      { afida_sku: product.sku, product_depth: "75mm", product_diameter: "90mm" }
    ])

    Rake::Task["products:import_specs"].invoke(csv_path)
    product.reload

    assert_equal 75, product.depth_in_mm
    assert_equal 90, product.diameter_in_mm
  end

  test "converts depth and diameter from cm and inches" do
    product = products(:one)
    csv_path = write_csv([
      { afida_sku: product.sku, product_depth: "7.5 cm", product_diameter: "3 inches" }
    ])

    Rake::Task["products:import_specs"].invoke(csv_path)
    product.reload

    assert_equal 75, product.depth_in_mm
    assert_equal 76, product.diameter_in_mm
  end

  test "updates product volume in ml" do
    product = products(:one)
    csv_path = write_csv([
      { afida_sku: product.sku, product_volume: "250ml" }
    ])

    Rake::Task["products:import_specs"].invoke(csv_path)
    product.reload

    assert_equal 250, product.volume_in_ml
  end

  test "converts litres to ml" do
    product = products(:one)
    csv_path = write_csv([
      { afida_sku: product.sku, product_volume: "1.5 L" }
    ])

    Rake::Task["products:import_specs"].invoke(csv_path)
    product.reload

    assert_equal 1500, product.volume_in_ml
  end

  test "converts cubic metres to ml" do
    product = products(:one)
    csv_path = write_csv([
      { afida_sku: product.sku, product_volume: "0.058m³" }
    ])

    Rake::Task["products:import_specs"].invoke(csv_path)
    product.reload

    assert_equal 58_000, product.volume_in_ml
  end

  test "skips null-like volume values" do
    product = products(:one)
    product.update_columns(volume_in_ml: 999)

    csv_path = write_csv([
      { afida_sku: product.sku, product_volume: "Not specified" }
    ])

    Rake::Task["products:import_specs"].invoke(csv_path)
    product.reload

    assert_equal 999, product.volume_in_ml
  end

  private

  def write_csv(rows)
    headers = %w[afida_sku ppp_sku name category size material colour pack_size pack_price certifications description website_url product_weight product_length product_width product_height product_depth product_diameter product_volume case_length case_width case_depth case_volume case_weight additional_specs]
    path = Rails.root.join("tmp", "test_specs_#{SecureRandom.hex(4)}.csv")

    CSV.open(path, "w") do |csv|
      csv << headers
      rows.each do |row|
        csv << headers.map { |h| row[h.to_sym] }
      end
    end

    path.to_s
  end
end
