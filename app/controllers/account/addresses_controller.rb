module Account
  class AddressesController < ApplicationController
    before_action :require_authentication
    before_action :set_address, only: [ :edit, :update, :destroy, :set_default ]

    # Rate limit address creation to prevent abuse (10 per hour per user)
    rate_limit to: 10, within: 1.hour, only: [ :create, :create_from_order ], with: -> {
      redirect_to account_addresses_path, alert: "Too many addresses created. Please try again later."
    }

    def index
      @addresses = Current.user.addresses.default_first
    end

    def new
      @address = Current.user.addresses.build
    end

    def create
      @address = Current.user.addresses.build(address_params)

      if @address.save
        respond_to do |format|
          format.html { redirect_to account_addresses_path, notice: "Address saved successfully." }
          format.turbo_stream
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @address.update(address_params)
        respond_to do |format|
          format.html { redirect_to account_addresses_path, notice: "Address updated successfully." }
          format.turbo_stream
        end
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @address.destroy!

      respond_to do |format|
        format.html { redirect_to account_addresses_path, notice: "Address deleted." }
        format.turbo_stream
      end
    end

    def set_default
      @address.update!(default: true)

      respond_to do |format|
        format.html { redirect_to account_addresses_path, notice: "Default address updated." }
        format.turbo_stream
      end
    end

    # POST /account/addresses/create_from_order
    # Creates address from order shipping details (used by US3)
    def create_from_order
      @order = Current.user.orders.find(params[:order_id])

      # Prevent duplicate addresses from rapid clicks
      if Current.user.has_matching_address?(line1: @order.shipping_address_line1, postcode: @order.shipping_postal_code)
        redirect_to confirmation_order_path(@order), notice: "Address already saved."
        return
      end

      @address = Current.user.addresses.build(
        nickname: params[:nickname],
        recipient_name: @order.shipping_name,
        line1: @order.shipping_address_line1,
        line2: @order.shipping_address_line2,
        city: @order.shipping_city,
        postcode: @order.shipping_postal_code,
        country: @order.shipping_country || "GB"
      )

      if @address.save
        redirect_to confirmation_order_path(@order), notice: "Address saved to your account."
      else
        redirect_to confirmation_order_path(@order), alert: "Could not save address. Please try again."
      end
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    private

    def set_address
      @address = Current.user.addresses.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def address_params
      params.require(:address).permit(
        :nickname, :recipient_name, :company_name,
        :line1, :line2, :city, :postcode, :country, :phone, :default
      )
    end
  end
end
