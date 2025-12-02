class Admin::ProductVariantsController < Admin::ApplicationController
  before_action :set_product_variant, only: [ :edit, :update, :destroy_product_photo, :destroy_lifestyle_photo ]

  def edit
  end

  def update
    if @product_variant.update(product_variant_params)
      redirect_to admin_product_variant_path(@product_variant), notice: "Product variant updated successfully"
    else
      render :edit
    end
  end

  # DELETE /admin/product_variants/:id/product_photo
  def destroy_product_photo
    @product_variant.product_photo.purge
    respond_to do |format|
      format.turbo_stream
      format.html { head :ok }
    end
  end

  # DELETE /admin/product_variants/:id/lifestyle_photo
  def destroy_lifestyle_photo
    @product_variant.lifestyle_photo.purge
    respond_to do |format|
      format.turbo_stream
      format.html { head :ok }
    end
  end

  private

  def set_product_variant
    @product_variant = ProductVariant.find(params[:id])
  end

  def product_variant_params
    params.expect(
      product_variant: [
        :name,
        :sku,
        :price,
        :active,
        :image,
        :width_in_mm,
        :height_in_mm,
        :depth_in_mm,
        :weight_in_g,
        :volume_in_ml,
        :diameter_in_mm,
        :sample_eligible,
        :sample_sku
      ]
    )
  end
end
