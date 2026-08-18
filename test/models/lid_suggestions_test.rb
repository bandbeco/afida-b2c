require "test_helper"

class LidSuggestionsTest < ActiveSupport::TestCase
  setup do
    @cart = Cart.create
    @cup = products(:branded_cup_8oz) # fixtures map it to flat_lid_8oz (default) + domed_lid_8oz
  end

  def add_to_cart(product, quantity: 1, is_sample: false)
    @cart.cart_items.create!(product: product, quantity: quantity, price: product.price || 0, is_sample: is_sample)
  end

  test "suggests the default lid for a lidless container" do
    add_to_cart(@cup)

    suggestions = LidSuggestions.new(@cart).to_a

    assert_equal [ products(:flat_lid_8oz) ], suggestions.map(&:lid)
    assert_equal [ [ @cup ] ], suggestions.map(&:containers)
  end

  test "falls back to the first lid by sort order when the default is inactive" do
    products(:flat_lid_8oz).update!(active: false)
    add_to_cart(@cup)

    suggestions = LidSuggestions.new(@cart).to_a

    assert_equal [ products(:domed_lid_8oz) ], suggestions.map(&:lid)
  end

  test "suggests nothing when a compatible lid is already in the cart" do
    add_to_cart(@cup)
    add_to_cart(products(:domed_lid_8oz))

    assert_empty LidSuggestions.new(@cart).to_a
  end

  test "suggests nothing for containers without compatible lids" do
    add_to_cart(products(:one))

    assert_empty LidSuggestions.new(@cart).to_a
  end

  test "dedupes to one suggestion when containers share a lid" do
    other_cup = products(:single_wall_8oz_white)
    ProductCompatibleLid.create!(product: other_cup, compatible_lid: products(:flat_lid_8oz), sort_order: 0, default: true)
    add_to_cart(@cup)
    add_to_cart(other_cup)

    suggestions = LidSuggestions.new(@cart).to_a

    assert_equal 1, suggestions.length
    assert_equal products(:flat_lid_8oz), suggestions.first.lid
    assert_equal [ @cup, other_cup ].sort_by(&:id), suggestions.first.containers.sort_by(&:id)
  end

  test "lists a container once even when it has two cart line items" do
    # Tiered pricing legitimately creates two rows for one product at different prices
    tiered_cup = products(:single_wall_8oz_white)
    ProductCompatibleLid.create!(product: tiered_cup, compatible_lid: products(:flat_lid_8oz), sort_order: 0, default: true)
    add_to_cart(tiered_cup)
    @cart.cart_items.create!(product: tiered_cup, quantity: 3, price: 24.00)

    suggestions = LidSuggestions.new(@cart).to_a

    assert_equal 1, suggestions.length
    assert_equal [ tiered_cup ], suggestions.first.containers
  end

  test "ignores sample items" do
    @cup.update!(sample_eligible: true)
    add_to_cart(@cup, is_sample: true)

    assert_empty LidSuggestions.new(@cart).to_a
  end

  test "skips containers whose lids are all inactive" do
    products(:flat_lid_8oz).update!(active: false)
    products(:domed_lid_8oz).update!(active: false)
    add_to_cart(@cup)

    assert_empty LidSuggestions.new(@cart).to_a
  end

  test "is empty for an empty cart" do
    assert_empty LidSuggestions.new(@cart).to_a
  end

  test "cart exposes lid_suggestions" do
    add_to_cart(@cup)

    assert_equal [ products(:flat_lid_8oz) ], @cart.lid_suggestions.map(&:lid)
  end
end
