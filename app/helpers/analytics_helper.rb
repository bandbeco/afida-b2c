# frozen_string_literal: true

# Helper methods for GA4 e-commerce tracking via Google Tag Manager
#
# These methods format product and order data for GA4's Enhanced E-commerce schema.
# Data is pushed to the dataLayer and processed by GTM tags.
#
# GA4 E-commerce events tracked:
# - view_item: Product detail page views
# - add_to_cart: Items added to cart
# - remove_from_cart: Items removed from cart
# - view_cart: Cart page views
# - begin_checkout: Checkout initiated
# - purchase: Order completed
#
# Usage in views:
#   <script><%= ecommerce_view_item_event(@product) %></script>
#
module AnalyticsHelper
  CURRENCY = "GBP"

  # Formats a product as a GA4 item object
  # @param product [Product] The product to format
  # @param quantity [Integer] Optional quantity (default: 1)
  # @return [Hash] GA4-compatible item hash
  def ga4_item(product, quantity: 1)
    {
      item_id: product.sku,
      item_name: product.generated_title,
      item_category: product.category&.name,
      price: product.price.to_f,
      quantity: quantity
    }.compact
  end

  # Formats a cart item as a GA4 item object
  # @param cart_item [CartItem] The cart item to format
  # @return [Hash] GA4-compatible item hash
  def ga4_cart_item(cart_item)
    product = cart_item.product

    {
      item_id: product.sku,
      item_name: product.generated_title,
      item_category: product.category&.name,
      price: cart_item.unit_price.to_f,
      quantity: cart_item.quantity
    }.compact
  end

  # Formats an order item as a GA4 item object
  # @param order_item [OrderItem] The order item to format
  # @return [Hash] GA4-compatible item hash
  def ga4_order_item(order_item)
    {
      item_id: order_item.product_sku,
      item_name: order_item.product_name,
      item_category: order_item.product&.category&.name,
      price: order_item.unit_price.to_f,
      quantity: order_item.quantity
    }.compact
  end

  # Generates JavaScript for view_item event (product detail page)
  # @param product [Product] The product being viewed
  # @return [String] JavaScript dataLayer.push code
  def ecommerce_view_item_event(product)
    return "" unless gtm_enabled?

    event_data = {
      event: "view_item",
      ecommerce: {
        currency: CURRENCY,
        value: product.price.to_f,
        items: [ ga4_item(product) ]
      }
    }

    ecommerce_push(event_data)
  end

  # Generates JavaScript for add_to_cart event
  # @param product [Product] The product being added
  # @param quantity [Integer] Quantity being added
  # @param value [Float] Total value being added
  # @return [String] JavaScript dataLayer.push code
  def ecommerce_add_to_cart_event(product, quantity:, value:)
    return "" unless gtm_enabled?

    event_data = {
      event: "add_to_cart",
      ecommerce: {
        currency: CURRENCY,
        value: value.to_f,
        items: [ ga4_item(product, quantity: quantity) ]
      }
    }

    ecommerce_push(event_data)
  end

  # Generates JavaScript for remove_from_cart event
  # @param cart_item [CartItem] The item being removed
  # @return [String] JavaScript dataLayer.push code
  def ecommerce_remove_from_cart_event(cart_item)
    return "" unless gtm_enabled?

    event_data = {
      event: "remove_from_cart",
      ecommerce: {
        currency: CURRENCY,
        value: cart_item.subtotal_amount.to_f,
        items: [ ga4_cart_item(cart_item) ]
      }
    }

    ecommerce_push(event_data)
  end

  # Generates JavaScript for remove_from_cart event using product data
  # Use when the cart item has been destroyed but you have product info
  # @param product [Product] The product being removed
  # @param quantity [Integer] Quantity being removed
  # @param value [Float] Total value being removed
  # @return [String] JavaScript dataLayer.push code
  def ecommerce_remove_from_cart_event_for_product(product, quantity:, value:)
    return "" unless gtm_enabled?

    event_data = {
      event: "remove_from_cart",
      ecommerce: {
        currency: CURRENCY,
        value: value.to_f,
        items: [ ga4_item(product, quantity: quantity) ]
      }
    }

    ecommerce_push(event_data)
  end

  # Generates JavaScript for view_cart event
  # @param cart [Cart] The cart being viewed
  # @return [String] JavaScript dataLayer.push code
  def ecommerce_view_cart_event(cart)
    return "" unless gtm_enabled?

    items = cart.cart_items.includes(:product).map { |item| ga4_cart_item(item) }

    event_data = {
      event: "view_cart",
      ecommerce: {
        currency: CURRENCY,
        value: cart.subtotal_amount.to_f,
        items: items
      }
    }

    ecommerce_push(event_data)
  end

  # Generates JavaScript for begin_checkout event
  # @param cart [Cart] The cart being checked out
  # @return [String] JavaScript dataLayer.push code
  def ecommerce_begin_checkout_event(cart)
    return "" unless gtm_enabled?

    items = cart.cart_items.includes(:product).map { |item| ga4_cart_item(item) }

    event_data = {
      event: "begin_checkout",
      ecommerce: {
        currency: CURRENCY,
        value: cart.total_amount.to_f,
        items: items
      }
    }

    ecommerce_push(event_data)
  end

  # Generates JavaScript for purchase event (order confirmation)
  # @param order [Order] The completed order
  # @return [String] JavaScript dataLayer.push code
  def ecommerce_purchase_event(order)
    return "" unless gtm_enabled?

    items = order.order_items.includes(:product).map { |item| ga4_order_item(item) }

    event_data = {
      event: "purchase",
      ecommerce: {
        transaction_id: order.order_number,
        value: order.total_amount.to_f,
        tax: order.vat_amount.to_f,
        shipping: order.shipping_amount.to_f,
        currency: CURRENCY,
        items: items
      }
    }

    ecommerce_push(event_data)
  end

  # Returns raw item data for use in JavaScript (Stimulus controllers)
  # @param product [Product] The product
  # @param quantity [Integer] Optional quantity
  # @return [Hash] GA4-compatible item data
  def ga4_item_json(product, quantity: 1)
    ga4_item(product, quantity: quantity).to_json.html_safe
  end

  # Returns cart items as JSON array for Stimulus controller data attributes
  # @param cart [Cart] The cart
  # @return [String] JSON array of GA4-compatible items
  def ga4_cart_items_json(cart)
    items = cart.cart_items.includes(:product).map { |item| ga4_cart_item(item) }
    items.to_json.html_safe
  end

  private

  def gtm_enabled?
    Rails.application.config.x.gtm_container_id.present?
  end

  # Generates dataLayer.push JavaScript with ecommerce null clearing
  # GA4 requires clearing previous ecommerce data before pushing new events
  def ecommerce_push(event_data)
    <<~JS.html_safe
      dataLayer.push({ ecommerce: null });
      dataLayer.push(#{event_data.to_json});
    JS
  end
end
