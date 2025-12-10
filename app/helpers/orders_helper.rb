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
end
