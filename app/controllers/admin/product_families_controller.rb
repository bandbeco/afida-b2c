module Admin
  class ProductFamiliesController < Admin::ApplicationController
    before_action :set_product_family, only: %i[ edit update destroy ]

    # GET /admin/product-families
    def index
      @product_families = ProductFamily.left_joins(:products)
                                       .select("product_families.*, COUNT(products.id) AS products_count")
                                       .group("product_families.id")
                                       .order(:name)
    end

    # GET /admin/product-families/new
    def new
      @product_family = ProductFamily.new
    end

    # GET /admin/product-families/:id/edit
    def edit
    end

    # POST /admin/product-families
    def create
      @product_family = ProductFamily.new(product_family_params)

      if @product_family.save
        redirect_to admin_product_families_path, notice: "Product family was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /admin/product-families/:id
    def update
      if @product_family.update(product_family_params)
        redirect_to admin_product_families_path, notice: "Product family was successfully updated.", status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/product-families/:id
    def destroy
      @product_family.destroy!
      redirect_to admin_product_families_path, notice: "Product family was successfully deleted.", status: :see_other
    end

    private

    def set_product_family
      @product_family = ProductFamily.find_by!(slug: params[:id])
    end

    def product_family_params
      params.expect(product_family: [ :name, :slug ])
    end
  end
end
