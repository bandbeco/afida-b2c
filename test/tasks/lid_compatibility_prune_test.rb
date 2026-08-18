# frozen_string_literal: true

require "test_helper"
require "rake"

class LidCompatibilityPruneTaskTest < ActiveSupport::TestCase
  setup do
    Shop::Application.load_tasks unless Rake::Task.task_defined?("lid_compatibility:prune_size_mismatched")
    ENV["APPLY"] = "1"
  end

  teardown do
    Rake::Task["lid_compatibility:prune_size_mismatched"].reenable
    ENV.delete("APPLY")
  end

  test "removes join rows whose lid oz size does not match the product's" do
    cup = products(:branded_cup_8oz)
    mismatched = ProductCompatibleLid.create!(product: cup, compatible_lid: products(:single_wall_12oz_white), sort_order: 3)

    capture_io { Rake::Task["lid_compatibility:prune_size_mismatched"].invoke }

    assert_not ProductCompatibleLid.exists?(mismatched.id)
    assert_equal [ products(:flat_lid_8oz).id, products(:domed_lid_8oz).id ].sort,
                 cup.compatible_lids.reload.ids.sort
  end

  test "removes all join rows when the product has no oz size token" do
    product = products(:one)
    ProductCompatibleLid.create!(product: product, compatible_lid: products(:flat_lid_8oz), sort_order: 1)

    capture_io { Rake::Task["lid_compatibility:prune_size_mismatched"].invoke }

    assert_empty product.compatible_lids.reload
  end

  test "skips customizable_template products entirely" do
    template = products(:branded_template_variant)
    row = ProductCompatibleLid.create!(product: template, compatible_lid: products(:flat_lid_8oz), sort_order: 1)

    capture_io { Rake::Task["lid_compatibility:prune_size_mismatched"].invoke }

    assert ProductCompatibleLid.exists?(row.id)
  end

  test "promotes the lowest sort_order survivor when the default row is pruned" do
    cup = products(:branded_cup_8oz)
    ProductCompatibleLid.create!(product: cup, compatible_lid: products(:single_wall_12oz_white), sort_order: 0, default: true)

    capture_io { Rake::Task["lid_compatibility:prune_size_mismatched"].invoke }

    defaults = ProductCompatibleLid.where(product_id: cup.id, default: true)
    assert_equal [ products(:flat_lid_8oz).id ], defaults.map(&:compatible_lid_id)
  end

  test "dry run changes nothing without APPLY" do
    ENV.delete("APPLY")
    cup = products(:branded_cup_8oz)
    mismatched = ProductCompatibleLid.create!(product: cup, compatible_lid: products(:single_wall_12oz_white), sort_order: 3)

    capture_io { Rake::Task["lid_compatibility:prune_size_mismatched"].invoke }

    assert ProductCompatibleLid.exists?(mismatched.id)
  end
end
