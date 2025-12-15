# frozen_string_literal: true

# Service object for reordering items from a previous order
#
# Takes an order and cart, checks item availability, and adds available items to cart.
# Returns a result object with success status, added count, and skipped items.
#
# Usage:
#   result = ReorderService.call(order: order, cart: cart)
#   if result.success?
#     redirect_to cart_path, notice: "#{result.added_count} items added"
#   else
#     redirect_to orders_path, alert: result.error
#   end
#
class ReorderService
  Result = Data.define(:success?, :added_count, :skipped_items, :error, :cart)

  def self.call(order:, cart:)
    new(order, cart).call
  end

  def initialize(order, cart)
    @order = order
    @cart = cart
    @added_count = 0
    @skipped_items = []
    # Preload cart items indexed by variant ID to avoid N+1 queries
    @existing_cart_items = @cart.cart_items.index_by(&:product_variant_id)
  end

  def call
    return failure("Order has no items") if @order.order_items.empty?

    process_order_items
    build_result
  end

  private

  def process_order_items
    @order.order_items.each do |item|
      if can_reorder?(item)
        add_to_cart(item)
      else
        skip_item(item)
      end
    end
  end

  def can_reorder?(item)
    return false if item.sample?
    return false if item.configured?
    return false unless item.product_variant.present?
    return false unless item.product_variant.active?
    return false unless item.product_variant.product&.active?

    true
  end

  def add_to_cart(item)
    variant = item.product_variant
    existing_cart_item = @existing_cart_items[variant.id]

    if existing_cart_item
      # Merge: add quantity to existing item
      existing_cart_item.update!(quantity: existing_cart_item.quantity + item.quantity)
    else
      # New item: use current price from variant
      new_item = @cart.cart_items.create!(
        product_variant: variant,
        price: variant.price,
        quantity: item.quantity
      )
      # Add to cache in case same variant appears again in order
      @existing_cart_items[variant.id] = new_item
    end

    @added_count += 1
  end

  def skip_item(item)
    @skipped_items << {
      name: item.product_name,
      reason: skip_reason(item)
    }
  end

  def skip_reason(item)
    return "This was a sample item" if item.sample?
    return "This was a configured/branded item" if item.configured?
    return "Product no longer exists" if item.product_variant.blank?
    return "Product is no longer available" unless item.product_variant.active?
    return "Product is no longer available" unless item.product_variant.product&.active?

    "Unknown reason"
  end

  def build_result
    if @added_count > 0
      Result.new(
        success?: true,
        added_count: @added_count,
        skipped_items: @skipped_items,
        error: nil,
        cart: @cart
      )
    else
      Result.new(
        success?: false,
        added_count: 0,
        skipped_items: @skipped_items,
        error: "No items could be added to your cart. All items are no longer available.",
        cart: @cart
      )
    end
  end

  def failure(message)
    Result.new(
      success?: false,
      added_count: 0,
      skipped_items: [],
      error: message,
      cart: @cart
    )
  end
end
