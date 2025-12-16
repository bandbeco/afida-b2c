# frozen_string_literal: true

class PendingOrderSnapshotBuilder
  VAT_RATE = 0.20
  FREE_SHIPPING_THRESHOLD = 100.00
  STANDARD_SHIPPING = 6.99

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

    subtotal = calculate_subtotal(available_items)
    vat = calculate_vat(subtotal)
    shipping = calculate_shipping(subtotal)
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

  private

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
      "price" => format_amount(current_price),
      "line_total" => format_amount(current_price * item.quantity),
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
      "variant_name" => variant&.display_name || "Unknown",
      "reason" => reason
    }
  end

  def calculate_subtotal(items)
    items.sum { |item| item["line_total"].to_d }
  end

  def calculate_vat(subtotal)
    subtotal * VAT_RATE
  end

  def calculate_shipping(subtotal)
    subtotal >= FREE_SHIPPING_THRESHOLD ? 0 : STANDARD_SHIPPING
  end

  def format_amount(amount)
    "%.2f" % amount
  end
end
