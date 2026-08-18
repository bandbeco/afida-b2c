# The cart's "Don't forget lids" suggestions: for every non-sample container
# in the cart that has curated compatible lids but none of them in the cart,
# suggest one lid (the curated default, falling back to the first active lid
# by sort order). Containers sharing a suggested lid collapse into a single
# suggestion so the cart never offers the same lid twice.
class LidSuggestions
  Suggestion = Struct.new(:lid, :containers)

  def initialize(cart)
    @cart = cart
  end

  def to_a
    cart_product_ids = cart_products.map(&:id).to_set

    cart_products
      .filter_map { |product| suggested_lid_for(product, cart_product_ids) }
      .group_by(&:first)
      .map { |lid, pairs| Suggestion.new(lid, pairs.map(&:last)) }
  end

  private

  attr_reader :cart

  def cart_products
    @cart_products ||= cart.cart_items
                           .non_samples
                           .includes(product: { compatible_lids: { product_photo_attachment: :blob } })
                           .map(&:product)
  end

  def suggested_lid_for(container, cart_product_ids)
    lids = container.compatible_lids.select(&:active?)
    return if lids.empty?
    return if lids.any? { |lid| cart_product_ids.include?(lid.id) }

    lid = lids.find { |candidate| default_lid_ids(container).include?(candidate.id) } || lids.first
    [ lid, container ]
  end

  def default_lid_ids(container)
    @default_lid_ids ||= ProductCompatibleLid
                           .where(product_id: cart_products.map(&:id), default: true)
                           .pluck(:product_id, :compatible_lid_id)
                           .group_by(&:first)
                           .transform_values { |pairs| pairs.map(&:last) }
    @default_lid_ids.fetch(container.id, [])
  end
end
