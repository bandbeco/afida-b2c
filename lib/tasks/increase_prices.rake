# frozen_string_literal: true

namespace :prices do
  desc "Increase all product prices by 9%"
  task increase: :environment do
    multiplier = BigDecimal("1.09")
    updated = 0

    Product.standard.find_each do |product|
      product.price = (product.price * multiplier).round(2)

      if product.pricing_tiers.present?
        product.pricing_tiers = product.pricing_tiers.map do |tier|
          tier.merge("price" => (BigDecimal(tier["price"].to_s) * multiplier).round(2).to_s("F"))
        end
      end

      product.save!
      updated += 1
    end

    puts "Updated #{updated} products by 9%."
  end
end
