# frozen_string_literal: true

require "test_helper"
require "rake"

class IncreasePricesTaskTest < ActiveSupport::TestCase
  setup do
    Shop::Application.load_tasks unless Rake::Task.task_defined?("prices:increase")
  end

  teardown do
    Rake::Task["prices:increase"].reenable
  end

  test "increases product prices by 9%" do
    product = products(:one)
    original_price = product.price

    Rake::Task["prices:increase"].invoke

    product.reload
    expected = (original_price * 1.09).round(2)
    assert_equal expected, product.price
  end

  test "increases pricing tier prices by 9%" do
    product = products(:single_wall_8oz_white)
    original_tiers = product.pricing_tiers.deep_dup

    Rake::Task["prices:increase"].invoke

    product.reload
    product.pricing_tiers.each_with_index do |tier, i|
      original_price = BigDecimal(original_tiers[i]["price"].to_s)
      expected = (original_price * BigDecimal("1.09")).round(2).to_s("F")
      assert_equal expected, tier["price"].to_s, "Tier #{i} price mismatch"
    end
  end

  test "skips non-standard products" do
    template = products(:branded_template_variant)
    instance = products(:acme_cups_variant)
    template_price = template.price
    instance_price = instance.price

    Rake::Task["prices:increase"].invoke

    template.reload
    instance.reload
    assert_equal template_price, template.price
    assert_equal instance_price, instance.price
  end
end
