module BrandedProducts
  class LidsController < ApplicationController
    include ProductHelper
    allow_unauthenticated_access

    def compatible_lids
      # Require product_id to properly match lid type (not just size)
      cup_product = Product.find_by(id: params[:product_id])
      return render json: { lids: [] } unless cup_product

      cup_size = params[:size]
      return render json: { lids: [] } if cup_size.blank?

      # Get compatible lid products (matches material type via join table)
      # With new structure, lid products are direct Product records
      compatible_lid_products = compatible_lids_for_cup_product(cup_product)
      compatible_lid_products = Product.where(id: compatible_lid_products.pluck(:id))
                                       .includes(product_photo_attachment: :blob)
                                       .active

      # Filter lid products matching the cup size
      # Extract size from product size field (e.g., "8oz" from "8oz / 227ml")
      matching_lids = compatible_lid_products.select do |lid_product|
        lid_size = extract_size_from_product(lid_product)
        lid_size == cup_size
      end

      # Map to JSON response format
      lid_variants_data = matching_lids.map do |lid_product|
        {
          product_id: lid_product.id,
          product_name: lid_product.generated_title,
          product_slug: lid_product.slug,
          variant_id: lid_product.id,  # Product IS the variant now
          variant_name: lid_product.generated_title,
          name: lid_product.generated_title,
          material: lid_product.material,
          size: lid_product.size,
          image_url: lid_product.product_photo.attached? ? url_for(lid_product.product_photo.variant(resize_to_limit: [ 200, 200 ])) : nil,
          price: lid_product.price || 0,
          pac_size: lid_product.pac_size || 1000,
          sku: lid_product.sku
        }
      end

      render json: { lids: lid_variants_data }
    end
  end
end
