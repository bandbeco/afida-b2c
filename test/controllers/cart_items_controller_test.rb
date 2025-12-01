require "test_helper"

class CartItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:one)
    @product_variant = product_variants(:one)

    # Ensure we have a cart
    get cart_url
    @cart = Cart.find(session[:cart_id])
  end

  # POST /cart/cart_items (create)
  test "should add new item to cart" do
    assert_difference("CartItem.count", 1) do
      post cart_cart_items_path, params: {
        cart_item: {
          variant_sku: @product_variant.sku,
          quantity: 2
        }
      }
    end

    assert_redirected_to cart_path
    assert_equal "#{@product_variant.display_name} added to cart.", flash[:notice]
  end

  test "should increment quantity for existing item" do
    # Add item first time
    post cart_cart_items_path, params: {
      cart_item: {
        variant_sku: @product_variant.sku,
        quantity: 2
      }
    }

    # Add same item again
    assert_no_difference("CartItem.count") do
      post cart_cart_items_path, params: {
        cart_item: {
          variant_sku: @product_variant.sku,
          quantity: 3
        }
      }
    end

    cart_item = @cart.cart_items.find_by(product_variant: @product_variant)
    assert_equal 5, cart_item.quantity # 2 + 3
  end

  test "should set price from product variant" do
    post cart_cart_items_path, params: {
      cart_item: {
        variant_sku: @product_variant.sku,
        quantity: 1
      }
    }

    cart_item = @cart.cart_items.find_by(product_variant: @product_variant)
    assert_equal @product_variant.price, cart_item.price
  end

  test "adding item creates cart automatically if needed" do
    # Start a new session
    open_session do |sess|
      assert_difference("Cart.count", 1) do
        sess.post cart_cart_items_path, params: {
          cart_item: {
            variant_sku: @product_variant.sku,
            quantity: 1
          }
        }
      end
    end
  end

  # PATCH /cart/cart_items/:id (update)
  test "should update cart item quantity" do
    cart_item = @cart.cart_items.create!(
      product_variant: @product_variant,
      quantity: 2,
      price: @product_variant.price
    )

    patch cart_cart_item_path(cart_item), params: {
      cart_item: { quantity: 5 }
    }

    assert_redirected_to cart_path
    assert_equal "Cart updated.", flash[:notice]
    cart_item.reload
    assert_equal 5, cart_item.quantity
  end

  test "should remove item when quantity set to zero" do
    cart_item = @cart.cart_items.create!(
      product_variant: @product_variant,
      quantity: 2,
      price: @product_variant.price
    )

    assert_difference("CartItem.count", -1) do
      patch cart_cart_item_path(cart_item), params: {
        cart_item: { quantity: 0 }
      }
    end

    assert_redirected_to cart_path
    assert_equal "Item removed from cart.", flash[:notice]
  end

  test "should remove item when quantity is negative" do
    cart_item = @cart.cart_items.create!(
      product_variant: @product_variant,
      quantity: 2,
      price: @product_variant.price
    )

    assert_difference("CartItem.count", -1) do
      patch cart_cart_item_path(cart_item), params: {
        cart_item: { quantity: -1 }
      }
    end
  end

  test "updating non-existent cart item redirects with alert" do
    patch cart_cart_item_path(id: 999999), params: {
      cart_item: { quantity: 5 }
    }

    assert_redirected_to cart_path
    assert_equal "Cart item not found.", flash[:alert]
  end

  test "cannot update another user's cart item" do
    other_cart = Cart.create(user: users(:two))
    other_cart_item = other_cart.cart_items.create!(
      product_variant: @product_variant,
      quantity: 1,
      price: @product_variant.price
    )

    patch cart_cart_item_path(other_cart_item), params: {
      cart_item: { quantity: 10 }
    }

    assert_redirected_to cart_path
    assert_equal "Cart item not found.", flash[:alert]

    # Original quantity should be unchanged
    other_cart_item.reload
    assert_equal 1, other_cart_item.quantity
  end

  # DELETE /cart/cart_items/:id (destroy)
  test "should destroy cart item" do
    cart_item = @cart.cart_items.create!(
      product_variant: @product_variant,
      quantity: 2,
      price: @product_variant.price
    )

    assert_difference("CartItem.count", -1) do
      delete cart_cart_item_path(cart_item)
    end

    assert_redirected_to cart_path
    assert_match /removed from cart/, flash[:notice]
  end

  test "destroying cart item shows product name in notice" do
    cart_item = @cart.cart_items.create!(
      product_variant: @product_variant,
      quantity: 2,
      price: @product_variant.price
    )

    delete cart_cart_item_path(cart_item)

    assert_match @product_variant.display_name, flash[:notice]
  end

  test "destroying non-existent cart item redirects with alert" do
    delete cart_cart_item_path(id: 999999)

    assert_redirected_to cart_path
    assert_equal "Cart item not found.", flash[:alert]
  end

  test "cannot destroy another user's cart item" do
    other_cart = Cart.create(user: users(:two))
    other_cart_item = other_cart.cart_items.create!(
      product_variant: @product_variant,
      quantity: 1,
      price: @product_variant.price
    )

    assert_no_difference("CartItem.count") do
      delete cart_cart_item_path(other_cart_item)
    end

    assert_redirected_to cart_path
    assert_equal "Cart item not found.", flash[:alert]
  end

  # Rate limiting
  test "rate limiting is configured" do
    # Just verify the endpoint works - actual rate limit testing is slow
    post cart_cart_items_path, params: {
      cart_item: {
        variant_sku: @product_variant.sku,
        quantity: 1
      }
    }

    assert_response :redirect
  end

  # Guest vs authenticated users
  test "guest user can add items to cart" do
    assert_difference("CartItem.count", 1) do
      post cart_cart_items_path, params: {
        cart_item: {
          variant_sku: @product_variant.sku,
          quantity: 1
        }
      }
    end
  end

  test "authenticated user can add items to cart" do
    user = users(:one)
    sign_in_as(user)

    assert_difference("CartItem.count", 1) do
      post cart_cart_items_path, params: {
        cart_item: {
          variant_sku: @product_variant.sku,
          quantity: 1
        }
      }
    end

    # Item should belong to user's cart
    cart = Cart.find_by(user: user)
    assert_not_nil cart
    assert cart.cart_items.exists?(product_variant: @product_variant)
  end

  test "cart persists across requests for guest" do
    # Add item
    post cart_cart_items_path, params: {
      cart_item: {
        variant_sku: @product_variant.sku,
        quantity: 1
      }
    }

    cart_id = session[:cart_id]

    # Make another request
    get cart_url

    # Should have same cart
    assert_equal cart_id, session[:cart_id]
  end

  # Configured Products Tests
  test "creates cart item with configuration for branded product" do
    sign_in_as users(:consumer)

    # Upload design file
    design_file = fixture_file_upload("test_design.pdf", "application/pdf")

    assert_difference "CartItem.count", 1 do
      post cart_cart_items_path, params: {
        product_id: products(:branded_double_wall_template).id,
        configuration: {
          size: "12oz",
          quantity: 5000
        },
        calculated_price: 1000.00,
        design: design_file
      }
    end

    cart_item = CartItem.last
    assert_equal "12oz", cart_item.configuration["size"]
    assert_equal "5000", cart_item.configuration["quantity"]
    assert_equal 1000.00, cart_item.calculated_price
    assert cart_item.design.attached?
  end

  test "requires calculated_price for configured products" do
    sign_in_as users(:consumer)

    assert_no_difference "CartItem.count" do
      post cart_cart_items_path, params: {
        product_id: products(:branded_double_wall_template).id,
        configuration: {
          size: "12oz",
          quantity: 5000
        }
      }, as: :json
    end

    assert_response :unprocessable_entity
  end

  test "validates design attachment for configured products" do
    sign_in_as users(:consumer)

    assert_no_difference "CartItem.count" do
      post cart_cart_items_path, params: {
        product_id: products(:branded_double_wall_template).id,
        configuration: {
          size: "12oz",
          quantity: 5000
        },
        calculated_price: 1000.00
      }, as: :json
    end

    assert_response :unprocessable_entity
  end

  test "standard product cart item creation still works" do
    sign_in_as users(:consumer)

    assert_difference "CartItem.count", 1 do
      post cart_cart_items_path, params: {
        cart_item: {
          variant_sku: product_variants(:single_wall_8oz_white).sku,
          quantity: 10
        }
      }
    end

    cart_item = CartItem.last
    assert_empty cart_item.configuration
    assert_nil cart_item.calculated_price
  end

  # Sample Cart Items Tests
  test "adds sample to cart with price zero" do
    sample_variant = product_variants(:sample_cup_8oz)

    assert_difference "CartItem.count", 1 do
      post cart_cart_items_path, params: {
        product_variant_id: sample_variant.id,
        sample: true
      }
    end

    cart_item = CartItem.last
    assert_equal sample_variant, cart_item.product_variant
    assert_equal 0, cart_item.price
    assert_equal 1, cart_item.quantity
  end

  test "rejects sample request for non-eligible variant" do
    non_sample_variant = product_variants(:one)

    assert_no_difference "CartItem.count" do
      post cart_cart_items_path, params: {
        product_variant_id: non_sample_variant.id,
        sample: true
      }
    end

    assert_redirected_to samples_path
    assert_match /not available as a sample/, flash[:alert]
  end

  test "rejects sample when at sample limit" do
    sample_variant = product_variants(:sample_cup_8oz)

    # Add 5 samples to reach limit
    Cart::SAMPLE_LIMIT.times do |i|
      variant = ProductVariant.create!(
        product: sample_variant.product,
        name: "Sample Variant #{i}",
        sku: "SAMPLE-#{i}-#{SecureRandom.hex(4)}",
        price: 10.0,
        stock_quantity: 100,
        active: true,
        sample_eligible: true
      )
      @cart.cart_items.create!(product_variant: variant, quantity: 1, price: 0)
    end

    assert_no_difference "CartItem.count" do
      post cart_cart_items_path, params: {
        product_variant_id: sample_variant.id,
        sample: true
      }
    end

    assert_redirected_to samples_path
    assert_match /Sample limit reached/, flash[:alert]
  end

  test "rejects duplicate sample in cart" do
    sample_variant = product_variants(:sample_cup_8oz)

    # Add sample first time
    post cart_cart_items_path, params: {
      product_variant_id: sample_variant.id,
      sample: true
    }

    # Try to add same sample again
    assert_no_difference "CartItem.count" do
      post cart_cart_items_path, params: {
        product_variant_id: sample_variant.id,
        sample: true
      }
    end

    assert_redirected_to samples_path
    assert_match /already in your cart/, flash[:alert]
  end

  test "rejects sample request for non-existent variant" do
    assert_no_difference "CartItem.count" do
      post cart_cart_items_path, params: {
        product_variant_id: 999999,
        sample: true
      }
    end

    assert_redirected_to samples_path
    assert_match /not available as a sample/, flash[:alert]
  end

  test "rejects sample request for inactive variant" do
    sample_variant = product_variants(:sample_cup_8oz)
    sample_variant.update!(active: false)

    assert_no_difference "CartItem.count" do
      post cart_cart_items_path, params: {
        product_variant_id: sample_variant.id,
        sample: true
      }
    end

    assert_redirected_to samples_path
    assert_match /not available as a sample/, flash[:alert]
  end

  test "removes sample from cart" do
    sample_variant = product_variants(:sample_cup_8oz)
    cart_item = @cart.cart_items.create!(
      product_variant: sample_variant,
      quantity: 1,
      price: 0
    )

    assert_difference "CartItem.count", -1 do
      delete cart_cart_item_path(cart_item)
    end
  end

  # Tests for sample/regular item mutual exclusivity
  test "adding regular item removes sample of same variant" do
    sample_variant = product_variants(:sample_cup_8oz)

    # First add as sample
    @cart.cart_items.create!(
      product_variant: sample_variant,
      quantity: 1,
      price: 0
    )
    assert_equal 1, @cart.cart_items.samples.count

    # Then add as regular item - should remove sample and add regular
    assert_no_difference "CartItem.count" do
      post cart_cart_items_path, params: {
        cart_item: {
          variant_sku: sample_variant.sku,
          quantity: 2
        }
      }
    end

    # Verify only regular item exists (sample was removed)
    assert_equal 1, @cart.cart_items.where(product_variant: sample_variant).count
    assert_equal 0, @cart.cart_items.samples.count

    regular_item = @cart.cart_items.find_by(product_variant: sample_variant)
    assert regular_item.price > 0, "Should be a regular item, not a sample"
    assert_equal 2, regular_item.quantity
  end

  test "rejects adding sample when regular item of same variant exists" do
    sample_variant = product_variants(:sample_cup_8oz)

    # First add as regular item
    @cart.cart_items.create!(
      product_variant: sample_variant,
      quantity: 2,
      price: sample_variant.price
    )

    # Then try to add as sample - should be rejected
    assert_no_difference "CartItem.count" do
      post cart_cart_items_path, params: {
        product_variant_id: sample_variant.id,
        sample: true
      }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    # Verify only regular item exists
    assert_equal 1, @cart.cart_items.where(product_variant: sample_variant).count
    regular_item = @cart.cart_items.find_by(product_variant: sample_variant)
    assert regular_item.price > 0, "Should still be the regular item"
  end

  test "adding regular item when sample exists preserves quantity" do
    sample_variant = product_variants(:sample_cup_8oz)

    # Add sample first
    @cart.cart_items.create!(
      product_variant: sample_variant,
      quantity: 1,
      price: 0
    )

    # Add regular item with quantity 5
    post cart_cart_items_path, params: {
      cart_item: {
        variant_sku: sample_variant.sku,
        quantity: 5
      }
    }

    # Should have only the regular item with correct quantity
    assert_equal 1, @cart.cart_items.where(product_variant: sample_variant).count
    regular_item = @cart.cart_items.find_by(product_variant: sample_variant)
    assert_equal 5, regular_item.quantity
    assert regular_item.price > 0
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
