module Admin
  class CollectionsController < Admin::ApplicationController
    before_action :set_collection, only: %i[ show edit update destroy move_higher move_lower ]

    # GET /admin/collections
    def index
      @collections = Collection.includes(image_attachment: :blob).order(:position)
    end

    # GET /admin/collections/:id
    def show
      redirect_to edit_admin_collection_path(@collection)
    end

    # GET /admin/collections/new
    def new
      @collection = Collection.new
      @products = available_products
    end

    # GET /admin/collections/:id/edit
    def edit
      @products = available_products
    end

    # POST /admin/collections
    def create
      @collection = Collection.new(collection_params)

      if @collection.save
        redirect_to admin_collections_path, notice: "Collection was successfully created."
      else
        @products = available_products
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /admin/collections/:id
    def update
      if @collection.update(collection_params)
        redirect_to admin_collections_path, notice: "Collection was successfully updated.", status: :see_other
      else
        @products = available_products
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/collections/:id
    def destroy
      @collection.destroy!
      redirect_to admin_collections_path, notice: "Collection was successfully deleted.", status: :see_other
    end

    # GET /admin/collections/order
    def order
      @collections = Collection.order(:position)
    end

    # PATCH /admin/collections/:id/move_higher
    def move_higher
      @collection.move_higher
      @collections = Collection.order(:position)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to order_admin_collections_path }
      end
    end

    # PATCH /admin/collections/:id/move_lower
    def move_lower
      @collection.move_lower
      @collections = Collection.order(:position)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to order_admin_collections_path }
      end
    end

    private

    def set_collection
      @collection = Collection.find(params[:id])
    end

    def collection_params
      params.expect(collection: [
        :name, :slug, :description, :meta_title, :meta_description,
        :featured, :sample_pack, :image, product_ids: []
      ])
    end

    def available_products
      Product.active.catalog_products.includes(:category).order(:name)
    end
  end
end
