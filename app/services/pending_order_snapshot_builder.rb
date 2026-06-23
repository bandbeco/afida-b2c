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

    @schedule.reorder_schedule_items.includes(:product).each do |item|
      if item_available?(item)
        available_items << build_item(item)
      else
        unavailable_items << build_unavailable_item(item)
      end
    end

    build_snapshot(available_items, unavailable_items)
  end

  # Builds a snapshot from raw items array (used when editing pending orders)
  # items: array of { product_id:, quantity: }
  def self.build_from_items(items)
    available_items = items.filter_map do |item|
      product = Product.find_by(id: item[:product_id])
      next unless product&.active?

      current_price = product.price
      quantity = item[:quantity].to_i

      {
        "product_id" => product.id,
        "product_name" => product.generated_title || "Unknown Product",
        "variant_name" => product.generated_title,
        "quantity" => quantity,
        "price" => format_amount(current_price),
        "line_total" => format_amount(current_price * quantity),
        "available" => true
      }
    end

    build_snapshot(available_items, [])
  end

  # Shared logic for building the final snapshot hash. The order-totals formula
  # (VAT + free-shipping rule) lives in OrderTotals; this builder owns summing the
  # snapshot lines into a subtotal and freezing the money as 2dp strings. :charged
  # — a frozen snapshot has its shipping fixed at order time.
  def self.build_snapshot(available_items, unavailable_items)
    subtotal = available_items.sum { |item| item["line_total"].to_d }
    totals = OrderTotals.for(subtotal, shipping: :charged)

    {
      "items" => available_items,
      "subtotal" => format_amount(totals.subtotal),
      "vat" => format_amount(totals.vat),
      "shipping" => format_amount(totals.shipping),
      "total" => format_amount(totals.total),
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
    return false unless item.product&.active?

    true
  end

  def build_item(item)
    product = item.product
    current_price = product.price

    {
      "product_id" => product.id,
      "product_name" => product.generated_title || "Unknown Product",
      "variant_name" => product.generated_title,
      "quantity" => item.quantity,
      "price" => self.class.format_amount(current_price),
      "line_total" => self.class.format_amount(current_price * item.quantity),
      "available" => true
    }
  end

  def build_unavailable_item(item)
    product = item.product

    reason = if product.nil?
               "Product no longer exists"
    elsif !product.active?
               "Product is no longer available"
    else
               "Product no longer available"
    end

    {
      "product_id" => product&.id,
      "product_name" => product&.generated_title || "Unknown Product",
      "variant_name" => product&.generated_title || "Unknown",
      "reason" => reason
    }
  end
end
