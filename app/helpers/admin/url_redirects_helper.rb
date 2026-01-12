# frozen_string_literal: true

module Admin
  module UrlRedirectsHelper
    # Find a matching product for a redirect
    # With the new model structure where each Product is its own entity,
    # variant_params are no longer needed - the product itself is the target.
    #
    # @param product [Product] The product to return
    # @param variant_params [Hash] Legacy parameter (ignored)
    # @return [Product, nil] The product if present
    def find_matching_variant(product, variant_params)
      product
    end
  end
end
