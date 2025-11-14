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
      # Eager load variants and their attachments to prevent N+1 queries
      compatible_lid_products = compatible_lids_for_cup_product(cup_product)
      compatible_lid_products = Product.where(id: compatible_lid_products.pluck(:id))
                                       .includes(active_variants: :product_photo_attachment,
                                                product_photo_attachment: :blob)

      # For each compatible lid product, find variants matching the cup size
      lid_variants_data = compatible_lid_products.flat_map do |lid_product|
        # Find variants with matching size
        matching_variants = lid_product.active_variants.select do |variant|
          extract_size_from_variant_name(variant.name) == cup_size
        end

        # Map to JSON response format - return variant-level data
        matching_variants.map do |variant|
          {
            product_id: lid_product.id,
            product_name: lid_product.name,
            product_slug: lid_product.slug,
            variant_id: variant.id,
            variant_name: variant.name,
            name: "#{lid_product.name} - #{variant.name}", # Combined display name
            image_url: (variant.product_photo.attached? ? url_for(variant.product_photo.variant(resize_to_limit: [ 200, 200 ])) : nil) ||
                      (lid_product.product_photo.attached? ? url_for(lid_product.product_photo.variant(resize_to_limit: [ 200, 200 ])) : nil),
            price: variant.price || 0,
            pac_size: variant.pac_size || 1000,
            sku: variant.sku
          }
        end
      end

      render json: { lids: lid_variants_data }
    end
  end
end
