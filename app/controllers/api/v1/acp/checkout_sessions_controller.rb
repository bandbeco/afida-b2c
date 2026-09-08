# frozen_string_literal: true

module Api
  module V1
    module Acp
      class CheckoutSessionsController < Api::V1::ApplicationController
        rate_limit to: 10, within: 1.minute, only: :create, with: -> { render json: { error: "Rate limit exceeded" }, status: :too_many_requests }

        def create
          items = Array(params[:items])
          if items.empty?
            render json: { error: "items must be a non-empty array" }, status: :unprocessable_entity
            return
          end

          quantities = Hash.new(0)
          items.each do |item|
            slug = (item[:slug] || item["slug"]).to_s
            quantity = (item[:quantity] || item["quantity"]).to_i
            if slug.blank? || quantity < 1
              render json: { error: "each item needs slug and quantity >= 1" }, status: :unprocessable_entity
              return
            end

            quantities[slug] += quantity
          end

          products = Product.active.standard.where(slug: quantities.keys).index_by(&:slug)
          unknown = quantities.keys - products.keys
          if unknown.any?
            render json: { error: "unknown product #{unknown.first}" }, status: :unprocessable_entity
            return
          end

          cart = build_cart(products, quantities)

          result = Checkout::SessionBuilder.new(
            cart: cart,
            user: nil,
            discount_code: nil,
            datafast_visitor_id: nil,
            datafast_session_id: nil,
            success_url: success_checkout_url + "?session_id={CHECKOUT_SESSION_ID}",
            cancel_url: cancel_checkout_url,
            ui_mode: :hosted
          ).create

          render json: {
            id: result.session.id,
            status: "pending",
            checkout_url: result.session.url
          }, status: :created
        rescue ActiveRecord::RecordInvalid => error
          render json: { error: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
        rescue Stripe::StripeError => error
          render json: { error: error.message }, status: :bad_gateway
        end

        private

        # Repeated slugs are folded into one line: a second item for the same
        # product would trip CartItem's per-cart uniqueness rule. The whole cart
        # is one transaction so a line the model rejects leaves nothing behind.
        def build_cart(products, quantities)
          ApplicationRecord.transaction do
            cart = Cart.create!
            quantities.each do |slug, quantity|
              product = products.fetch(slug)
              cart.cart_items.create!(product: product, quantity: quantity, price: product.price)
            end
            cart
          end
        end
      end
    end
  end
end
