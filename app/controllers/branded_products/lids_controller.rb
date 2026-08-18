module BrandedProducts
  class LidsController < ApplicationController
    allow_unauthenticated_access

    # Lid candidates come exclusively from the curated product_compatible_lids
    # join table. The optional size param exists for customizable templates:
    # one template product spans many cup sizes, so its join rows hold lids of
    # every size and the configurator narrows to the selected size here.
    def compatible_lids
      cup_product = Product.find_by(id: params[:product_id])
      return render json: { lids: [] } unless cup_product

      lids = cup_product.compatible_lids
                        .includes(product_photo_attachment: :blob)
                        .active

      if params[:size].present?
        # Match on the oz token so composed sizes ("8oz Red") still resolve; a
        # size with no oz token matches nothing, mirroring the old behaviour.
        wanted = params[:size][/\d+oz/i]&.downcase
        lids = wanted ? lids.select { |lid| lid.oz_size_token == wanted } : []
      end

      render json: { lids: lids.map { |lid| lid_json(lid) } }
    end

    private

    def lid_json(lid_product)
      {
        product_id: lid_product.id,
        product_name: lid_product.generated_title,
        product_slug: lid_product.slug,
        variant_id: lid_product.id,
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
  end
end
