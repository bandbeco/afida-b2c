# frozen_string_literal: true

class PendingOrderSnapshotBuilder
  def initialize(schedule)
    @schedule = schedule
  end

  # Builds an items_snapshot hash with current prices for all schedule items
  # Returns hash suitable for storing in PendingOrder#items_snapshot
  def build
    available_items = []
    unavailable_items = []

    @schedule.reorder_schedule_items.includes(product_variant: :product).each do |item|
      if item_available?(item)
        available_items << build_item(item)
      else
        unavailable_items << build_unavailable_item(item)
      end
    end

    build_snapshot(available_items, unavailable_items)
  end

  # Builds a snapshot from raw items array (used when editing pending orders)
  # items: array of { product_variant_id:, quantity: }
  def self.build_from_items(items)
    available_items = items.filter_map do |item|
      variant = ProductVariant.find_by(id: item[:product_variant_id])
      next unless variant&.active? && variant.product&.active?

      current_price = variant.price
      quantity = item[:quantity].to_i

      {
        "product_variant_id" => variant.id,
        "product_name" => variant.product&.name || "Unknown Product",
        "variant_name" => variant.display_name,
        "quantity" => quantity,
        "price" => format_amount(current_price),
        "line_total" => format_amount(current_price * quantity),
        "available" => true
      }
    end

    build_snapshot(available_items, [])
  end

  # Shared logic for building the final snapshot hash
  def self.build_snapshot(available_items, unavailable_items)
    subtotal = available_items.sum { |item| item["line_total"].to_d }
    vat = subtotal * VAT_RATE
    shipping = subtotal >= Shipping::FREE_SHIPPING_THRESHOLD ? 0 : (Shipping::STANDARD_COST / 100.0)
    total = subtotal + vat + shipping

    {
      "items" => available_items,
      "subtotal" => format_amount(subtotal),
      "vat" => format_amount(vat),
      "shipping" => format_amount(shipping),
      "total" => format_amount(total),
      "unavailable_items" => unavailable_items
    }
  end

  def self.format_amount(amount)
    "%.2f" % amount
  end

  private

  def build_snapshot(available_items, unavailable_items)
    self.class.build_snapshot(available_items, unavailable_items)
  end

  def item_available?(item)
    return false unless item.product_variant&.active?
    return false unless item.product_variant&.product&.active?

    true
  end

  def build_item(item)
    variant = item.product_variant
    current_price = variant.price

    {
      "product_variant_id" => variant.id,
      "product_name" => variant.product&.name || "Unknown Product",
      "variant_name" => variant.display_name,
      "quantity" => item.quantity,
      "price" => self.class.format_amount(current_price),
      "line_total" => self.class.format_amount(current_price * item.quantity),
      "available" => true
    }
  end

  def build_unavailable_item(item)
    variant = item.product_variant

    reason = if variant.nil?
               "Product variant no longer exists"
    elsif !variant.active?
               "Product variant is no longer available"
    elsif !variant.product&.active?
               "Product is no longer available"
    else
               "Product no longer available"
    end

    {
      "product_variant_id" => variant&.id,
      "product_name" => variant&.product&.name || "Unknown Product",
      "variant_name" => variant&.name || "Unknown",
      "reason" => reason
    }
  end
end
