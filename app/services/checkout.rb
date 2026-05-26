module Checkout
  CART_ITEM_INCLUDES = [ :product, { design_attachment: :blob } ].freeze
end
