# frozen_string_literal: true

module OrdersHelper
  # Generates the appropriate order path based on authentication status
  # Authenticated users viewing their own orders don't need a token
  # Guest users and email links need a signed token for access
  def order_details_path_for(order)
    if Current.user && order.user_id == Current.user.id
      order_path(order)
    else
      order_path(order, token: order.signed_access_token)
    end
  end

  # The order-totals summary as an ordered list of display lines, the single
  # source of truth shared by every order surface (storefront pages, admin page,
  # confirmation emails, and the PDF). Delegates to OrderSummary so the line
  # order, labels, money format and discount-visibility rule live in one place;
  # this view-layer wrapper exists so templates can call a helper. See
  # OrderSummary for the shape of each line.
  def order_summary_lines(order)
    OrderSummary.lines(order)
  end

  # Our SKU for an order item, with the supplier SKU appended in parentheses when
  # known, e.g. "VEG-CC-9-7 (R300S-VW)". Used in internal ops views so admins can
  # cross-reference our catalogue against a supplier's. Prefers the SKU snapshot
  # captured on the order item; supplier SKU is only available on the live product.
  def order_item_sku_label(item)
    our_sku = item.product_sku.presence || item.product&.sku
    supplier_sku = item.product&.supplier_sku

    return our_sku if supplier_sku.blank?

    "#{our_sku} (#{supplier_sku})"
  end
end
