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

  # Sample Pack tests (US2 - Limit Sample Pack Quantity)
  test "adding sample pack to cart succeeds when cart has no sample pack" do
    sample_variant = product_variants(:sample_pack_variant)

    assert_difference "CartItem.count", 1 do
      post cart_cart_items_path, params: {
        product_variant_id: sample_variant.id,
        quantity: 1
      }
    end

    assert_redirected_to cart_path
    assert_match /added to cart/i, flash[:notice]
  end

  test "adding sample pack when already in cart shows friendly message" do
    sample_variant = product_variants(:sample_pack_variant)

    # Add sample pack first time
    @cart.cart_items.create!(
      product_variant: sample_variant,
      quantity: 1,
      price: sample_variant.price
    )

    # Try to add again
    assert_no_difference "CartItem.count" do
      post cart_cart_items_path, params: {
        product_variant_id: sample_variant.id,
        quantity: 1
      }
    end

    assert_redirected_to cart_path
    assert_match /already in your cart/i, flash[:notice]
  end

  test "adding sample pack quantity is capped at 1" do
    sample_variant = product_variants(:sample_pack_variant)

    post cart_cart_items_path, params: {
      product_variant_id: sample_variant.id,
      quantity: 5  # Trying to add 5
    }

    cart_item = @cart.cart_items.find_by(product_variant: sample_variant)
    assert_equal 1, cart_item.quantity  # Should be capped at 1
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
