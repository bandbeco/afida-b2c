module Admin
  class ProductsController < Admin::ApplicationController
    before_action :set_product, only: %i[ show edit update destroy new_variant destroy_product_photo destroy_lifestyle_photo add_compatible_lid remove_compatible_lid set_default_compatible_lid update_compatible_lids variants ]

    # GET /products
    def index
      @products = Product.all
    end

    # GET /products/1
    def show
    end

    # GET /products/new
    def new
      @product = Product.new
    end

    # GET /products/1/edit
    def edit
      # Product is the main entity now - just loading for editing
    end

    # POST /products
    def create
      @product = Product.new(product_params)

      if @product.save
        redirect_to admin_products_path, notice: "Product was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def new_variant
    end

    # PATCH/PUT /products/1
    def update
      if @product.update(product_params)
        redirect_to admin_product_path(@product), notice: "Product was successfully updated.", status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /products/1
    def destroy
      @product.destroy!
      redirect_to admin_products_path, notice: "Product was successfully destroyed.", status: :see_other
    end

    # DELETE /admin/products/:id/product_photo
    def destroy_product_photo
      @product.product_photo.purge
      respond_to do |format|
        format.turbo_stream
        format.html { head :ok }
      end
    end

    # DELETE /admin/products/:id/lifestyle_photo
    def destroy_lifestyle_photo
      @product.lifestyle_photo.purge
      respond_to do |format|
        format.turbo_stream
        format.html { head :ok }
      end
    end

    # GET /admin/products/order
    def order
      @categories = Category.order(:position)
      @selected_category = if params[:category_id]
        Category.find(params[:category_id])
      else
        @categories.first
      end

      @products = if @selected_category
        Product.unscoped
          .where(category_id: @selected_category.id)
          .order(:position)
      else
        []
      end
    end

    # PATCH /admin/products/:id/move_higher
    def move_higher
      @product = Product.unscoped.find_by!(slug: params[:id])
      @product.move_higher

      redirect_to order_admin_products_path(category_id: @product.category_id)
    end

    # PATCH /admin/products/:id/move_lower
    def move_lower
      @product = Product.unscoped.find_by!(slug: params[:id])
      @product.move_lower

      redirect_to order_admin_products_path(category_id: @product.category_id)
    end

    # POST /admin/products/:id/add_compatible_lid
    def add_compatible_lid
      lid = Product.find(params[:lid_id])

      # Get the next sort_order value
      next_sort_order = @product.product_compatible_lids.maximum(:sort_order).to_i + 1

      # Set as default if it's the first lid
      is_default = @product.product_compatible_lids.none?

      @product.product_compatible_lids.create!(
        compatible_lid: lid,
        sort_order: next_sort_order,
        default: is_default
      )

      redirect_to edit_admin_product_path(@product), notice: "Added #{lid.name} as compatible lid"
    end

    # DELETE /admin/products/:id/remove_compatible_lid
    def remove_compatible_lid
      lid = Product.find(params[:lid_id])
      pcl = @product.product_compatible_lids.find_by(compatible_lid: lid)

      if pcl
        was_default = pcl.default?
        pcl.destroy!

        # If we removed the default lid, set the first remaining lid as default
        if was_default && @product.product_compatible_lids.any?
          @product.product_compatible_lids.order(:sort_order).first.update!(default: true)
        end

        redirect_to edit_admin_product_path(@product), notice: "Removed #{lid.name} from compatible lids"
      else
        redirect_to edit_admin_product_path(@product), alert: "Lid not found in compatible lids"
      end
    end

    # PATCH /admin/products/:id/set_default_compatible_lid
    def set_default_compatible_lid
      lid = Product.find(params[:lid_id])
      pcl = @product.product_compatible_lids.find_by(compatible_lid: lid)

      if pcl
        # Unset all other defaults
        @product.product_compatible_lids.where(default: true).update_all(default: false)
        # Set this one as default
        pcl.update!(default: true)

        redirect_to edit_admin_product_path(@product), notice: "Set #{lid.name} as default lid"
      else
        redirect_to edit_admin_product_path(@product), alert: "Lid not found in compatible lids"
      end
    end

    # PATCH /admin/products/:id/update_compatible_lids
    def update_compatible_lids
      selected_lid_ids = params[:lid_ids]&.map(&:to_i) || []
      default_lid_id = params[:default_lid_id]&.to_i
      current_lid_ids = @product.product_compatible_lids.pluck(:compatible_lid_id)

      # Determine which lids to add and remove
      lids_to_add = selected_lid_ids - current_lid_ids
      lids_to_remove = current_lid_ids - selected_lid_ids

      # Remove unchecked lids
      @product.product_compatible_lids.where(compatible_lid_id: lids_to_remove).destroy_all

      # Add new lids
      lids_to_add.each_with_index do |lid_id, index|
        next_sort_order = @product.product_compatible_lids.maximum(:sort_order).to_i + 1 + index
        is_default = (lid_id == default_lid_id) || (@product.product_compatible_lids.none? && index == 0)

        @product.product_compatible_lids.create!(
          compatible_lid_id: lid_id,
          sort_order: next_sort_order,
          default: is_default
        )
      end

      # Update default if it changed among existing lids
      if default_lid_id.present? && selected_lid_ids.include?(default_lid_id)
        @product.product_compatible_lids.update_all(default: false)
        @product.product_compatible_lids.find_by(compatible_lid_id: default_lid_id)&.update!(default: true)
      end

      redirect_to edit_admin_product_path(@product), notice: "Updated compatible lids"
    end

    # GET /admin/products/:id/variants.json
    # Returns the product and its siblings (products in same family)
    def variants
      respond_to do |format|
        format.json do
          # With the new structure, "variants" are siblings in the same product family
          all_products = if @product.product_family_id.present?
            @product.product_family.products.active
          else
            Product.where(id: @product.id)
          end

          render json: {
            product: {
              id: @product.id,
              name: @product.name,
              slug: @product.slug
            },
            variants: all_products.map do |product|
              {
                id: product.id,
                name: product.name,
                display_name: product.name
              }
            end
          }
        end
      end
    end

    private
    # Use callbacks to share common setup or constraints between actions.
    def set_product
      @product = Product.unscoped.find_by!(slug: params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def product_params
      params.expect(product: [
        :active,
        :featured,
        :sample_eligible,
        :sample_sku,
        :name,
        :sku,
        :description_short,
        :description_standard,
        :description_detailed,
        :colour,
        :category_id,
        :product_family_id,
        :product_photo,
        :lifestyle_photo,
        :slug,
        :position,
        :meta_title,
        :meta_description,
        :meta_image,
        :pac_size,
        :price,
        :stock_quantity,
        :length_in_mm,
        :height_in_mm,
        :width_in_mm,
        :depth_in_mm,
        :weight_in_g,
        :volume_in_ml,
        :diameter_in_mm
      ])
    end
  end
end
