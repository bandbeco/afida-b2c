# frozen_string_literal: true

module Admin
  module UrlRedirectsHelper
    # Find a matching product for a redirect's variant_params
    # With the new model structure, Product IS the variant
    #
    # @param product [Product] The product to check
    # @param variant_params [Hash] The parameters to match (e.g., {size: "12oz", colour: "black"})
    # @return [Product, nil] The product if it matches, nil otherwise
    def find_matching_variant(product, variant_params)
      return nil unless product

      # If no variant_params, the product itself is the match
      return product if variant_params.blank?

      # Check if the product's option values match the params
      if product.respond_to?(:option_values_hash) && product.option_values_hash.present?
        matches = variant_params.all? { |key, value| product.option_values_hash[key.to_s] == value }
        matches ? product : nil
      else
        # Legacy redirects may have variant_params that don't apply anymore
        product
      end
    end
  end
end
