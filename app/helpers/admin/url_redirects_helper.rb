# frozen_string_literal: true

module Admin
  module UrlRedirectsHelper
    # Find a matching variant for a redirect's variant_params
    # Returns the variant if found, nil otherwise
    #
    # @param product [Product] The product to search within
    # @param variant_params [Hash] The parameters to match (e.g., {size: "12oz", colour: "black"})
    # @return [ProductVariant, nil] The matching variant or nil
    def find_matching_variant(product, variant_params)
      return nil unless product && variant_params.present?

      product.active_variants.find do |variant|
        variant_params.all? { |key, value| variant.option_values_hash[key.to_s] == value }
      end
    end
  end
end
