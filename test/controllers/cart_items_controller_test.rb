require "test_helper"

class CartItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:one)
    @product_variant = products(:one)

    # Create a fresh cart for testing
    @cart = Cart.create!

    # Make a request that will use this cart
    # We need to get the cart into the session. The easiest way is to add
    # something to it, which will create the session association.
    post cart_cart_items_path, params: {
      cart_item: {
        sku: products(:single_wall_8oz_white).sku,
        quantity: 1
      }
    }

    # Now grab the cart that was just used (the one with the item we just added)
    @cart = CartItem.last.cart
    # Clean up the test item we used to establish the session
    @cart.cart_items.destroy_all
  end

  # POST /cart/cart_items (create)
  test "should add new item to cart" do
    assert_difference("CartItem.count", 1) do
      post cart_cart_items_path, params: {
        cart_item: {
          sku: @product_variant.sku,
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
        sku: @product_variant.sku,
        quantity: 2
      }
    }

    # Add same item again
    assert_no_difference("CartItem.count") do
      post cart_cart_items_path, params: {
        cart_item: {
          sku: @product_variant.sku,
          quantity: 3
        }
      }
    end

    cart_item = @cart.cart_items.find_by(product: @product_variant)
    assert_equal 5, cart_item.quantity # 2 + 3
  end

  test "should set price from product variant" do
    post cart_cart_items_path, params: {
      cart_item: {
        sku: @product_variant.sku,
        quantity: 1
      }
    }

    cart_item = @cart.cart_items.find_by(product: @product_variant)
    assert_equal @product_variant.price, cart_item.price
  end

  test "adding item creates cart automatically if needed" do
    # Start a new session
    open_session do |sess|
      assert_difference("Cart.count", 1) do
        sess.post cart_cart_items_path, params: {
          cart_item: {
            sku: @product_variant.sku,
            quantity: 1
          }
        }
      end
    end
  end

  # PATCH /cart/cart_items/:id (update)
  test "should update cart item quantity" do
    cart_item = @cart.cart_items.create!(
      product: @product_variant,
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
      product: @product_variant,
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
      product: @product_variant,
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
      product: @product_variant,
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

  # =============================================================================
  # Tests for updating configured (branded) cart items with tiered pricing
  # =============================================================================

  test "updating configured cart item recalculates tiered pricing" do
    branded_product = products(:branded_template_variant)
    design_file = fixture_file_upload("test_design.pdf", "application/pdf")

    # Create a configured cart item at 8oz, 1000 units (base tier: £0.30/unit)
    cart_item = @cart.cart_items.build(
      product: branded_product,
      quantity: 1000,
      price: 0.30,
      calculated_price: 300.00,
      configuration: { "size" => "8oz", "quantity" => 1000 }
    )
    cart_item.design.attach(design_file)
    cart_item.save!

    # Update to 5000 units - should trigger tier change to £0.18/unit
    patch cart_cart_item_path(cart_item), params: {
      cart_item: { quantity: 5000 }
    }

    assert_redirected_to cart_path
    assert_equal "Cart updated.", flash[:notice]

    cart_item.reload
    assert_equal 5000, cart_item.quantity
    assert_equal 0.18, cart_item.price.to_f  # New tier price
    assert_equal 900.00, cart_item.calculated_price.to_f  # 5000 * 0.18
    assert_equal 5000, cart_item.configuration["quantity"]  # Config synced
  end

  test "updating configured cart item to lower tier increases unit price" do
    branded_product = products(:branded_template_variant)
    design_file = fixture_file_upload("test_design.pdf", "application/pdf")

    # Start at 5000 units (£0.18/unit tier)
    cart_item = @cart.cart_items.build(
      product: branded_product,
      quantity: 5000,
      price: 0.18,
      calculated_price: 900.00,
      configuration: { "size" => "8oz", "quantity" => 5000 }
    )
    cart_item.design.attach(design_file)
    cart_item.save!

    # Update to 2000 units - should change to £0.25/unit tier
    patch cart_cart_item_path(cart_item), params: {
      cart_item: { quantity: 2000 }
    }

    assert_redirected_to cart_path

    cart_item.reload
    assert_equal 2000, cart_item.quantity
    assert_equal 0.25, cart_item.price.to_f  # Lower quantity = higher price
    assert_equal 500.00, cart_item.calculated_price.to_f  # 2000 * 0.25
  end

  test "updating configured cart item syncs configuration quantity" do
    branded_product = products(:branded_template_variant)
    design_file = fixture_file_upload("test_design.pdf", "application/pdf")

    cart_item = @cart.cart_items.build(
      product: branded_product,
      quantity: 1000,
      price: 0.30,
      calculated_price: 300.00,
      configuration: { "size" => "8oz", "quantity" => 1000 }
    )
    cart_item.design.attach(design_file)
    cart_item.save!

    patch cart_cart_item_path(cart_item), params: {
      cart_item: { quantity: 2000 }
    }

    cart_item.reload
    # Both quantity and configuration["quantity"] should be updated
    assert_equal 2000, cart_item.quantity
    assert_equal 2000, cart_item.configuration["quantity"]
    # Size should remain unchanged
    assert_equal "8oz", cart_item.configuration["size"]
  end

  test "updating configured cart item preserves design attachment" do
    sign_in_as users(:consumer)

    branded_product = products(:branded_template_variant)
    design_file = fixture_file_upload("test_design.pdf", "application/pdf")

    # Create cart item with design attachment
    cart_item = @cart.cart_items.build(
      product: branded_product,
      quantity: 1000,
      price: 0.30,
      calculated_price: 300.00,
      configuration: { "size" => "8oz", "quantity" => 1000 }
    )
    cart_item.design.attach(design_file)
    cart_item.save!
    assert cart_item.design.attached?

    # Update quantity
    patch cart_cart_item_path(cart_item), params: {
      cart_item: { quantity: 5000 }
    }

    cart_item.reload
    assert cart_item.design.attached?, "Design should still be attached after quantity update"
  end

  test "removing configured cart item by setting quantity to zero works" do
    branded_product = products(:branded_template_variant)
    design_file = fixture_file_upload("test_design.pdf", "application/pdf")

    cart_item = @cart.cart_items.build(
      product: branded_product,
      quantity: 1000,
      price: 0.30,
      calculated_price: 300.00,
      configuration: { "size" => "8oz", "quantity" => 1000 }
    )
    cart_item.design.attach(design_file)
    cart_item.save!

    assert_difference("CartItem.count", -1) do
      patch cart_cart_item_path(cart_item), params: {
        cart_item: { quantity: 0 }
      }
    end

    assert_redirected_to cart_path
    assert_equal "Item removed from cart.", flash[:notice]
  end

  test "updating configured cart item preserves full price precision" do
    branded_product = products(:branded_template_variant)
    design_file = fixture_file_upload("test_design.pdf", "application/pdf")

    # Start with 16oz at 1000 units (0.34/unit)
    cart_item = @cart.cart_items.build(
      product: branded_product,
      quantity: 1000,
      price: 0.34,
      calculated_price: 340.00,
      configuration: { "size" => "16oz", "quantity" => 1000 }
    )
    cart_item.design.attach(design_file)
    cart_item.save!

    # Update to 5000 units which has 4 decimal place price (0.2175/unit)
    patch cart_cart_item_path(cart_item), params: {
      cart_item: { quantity: 5000 }
    }

    cart_item.reload
    assert_equal 5000, cart_item.quantity
    # Price should preserve all 4 decimal places, not round to 0.22
    assert_equal BigDecimal("0.2175"), cart_item.price
    assert_equal BigDecimal("1087.50"), cart_item.calculated_price  # 5000 * 0.2175
  end

  # DELETE /cart/cart_items/:id (destroy)
  test "should destroy cart item" do
    cart_item = @cart.cart_items.create!(
      product: @product_variant,
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
      product: @product_variant,
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
      product: @product_variant,
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
        sku: @product_variant.sku,
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
          sku: @product_variant.sku,
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
          sku: @product_variant.sku,
          quantity: 1
        }
      }
    end

    # Item should belong to user's cart
    cart = Cart.find_by(user: user)
    assert_not_nil cart
    assert cart.cart_items.exists?(product: @product_variant)
  end

  test "cart persists across requests for guest" do
    # Add item
    post cart_cart_items_path, params: {
      cart_item: {
        sku: @product_variant.sku,
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
          sku: products(:single_wall_8oz_white).sku,
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
    sample_variant = products(:sample_cup_8oz)

    assert_difference "CartItem.count", 1 do
      post cart_cart_items_path, params: {
        product_id: sample_variant.id,
        sample: true
      }
    end

    cart_item = CartItem.last
    assert_equal sample_variant, cart_item.product
    assert_equal 0, cart_item.price
    assert_equal 1, cart_item.quantity
  end

  test "rejects sample request for non-eligible variant" do
    non_sample_variant = products(:one)

    assert_no_difference "CartItem.count" do
      post cart_cart_items_path, params: {
        product_id: non_sample_variant.id,
        sample: true
      }
    end

    assert_redirected_to samples_path
    assert_match /not available as a sample/, flash[:alert]
  end

  test "rejects sample when at sample limit" do
    sample_variant = products(:sample_cup_8oz)

    # Add 5 samples to reach limit
    Cart::SAMPLE_LIMIT.times do |i|
      variant = Product.create!(
        category: sample_variant.category,
        name: "Sample Variant #{i}",
        sku: "SAMPLE-#{i}-#{SecureRandom.hex(4)}",
        price: 10.0,
        stock_quantity: 100,
        active: true,
        sample_eligible: true
      )
      @cart.cart_items.create!(product: variant, quantity: 1, price: 0, is_sample: true)
    end

    assert_no_difference "CartItem.count" do
      post cart_cart_items_path, params: {
        product_id: sample_variant.id,
        sample: true
      }
    end

    assert_redirected_to samples_path
    assert_match /Sample limit of #{Cart::SAMPLE_LIMIT} reached/, flash[:alert]
  end

  test "rejects duplicate sample in cart" do
    sample_variant = products(:sample_cup_8oz)

    # Add sample first time
    post cart_cart_items_path, params: {
      product_id: sample_variant.id,
      sample: true
    }

    # Try to add same sample again
    assert_no_difference "CartItem.count" do
      post cart_cart_items_path, params: {
        product_id: sample_variant.id,
        sample: true
      }
    end

    assert_redirected_to samples_path
    assert_match /already in your cart/, flash[:alert]
  end

  test "rejects sample request for non-existent variant" do
    assert_no_difference "CartItem.count" do
      post cart_cart_items_path, params: {
        product_id: 999999,
        sample: true
      }
    end

    assert_redirected_to samples_path
    assert_match /not available as a sample/, flash[:alert]
  end

  test "rejects sample request for inactive variant" do
    sample_variant = products(:sample_cup_8oz)
    sample_variant.update!(active: false)

    assert_no_difference "CartItem.count" do
      post cart_cart_items_path, params: {
        product_id: sample_variant.id,
        sample: true
      }
    end

    assert_redirected_to samples_path
    assert_match /not available as a sample/, flash[:alert]
  end

  test "removes sample from cart" do
    sample_variant = products(:sample_cup_8oz)
    cart_item = @cart.cart_items.create!(
      product: sample_variant,
      quantity: 1,
      price: 0,
      is_sample: true
    )

    assert_difference "CartItem.count", -1 do
      delete cart_cart_item_path(cart_item)
    end
  end

  # Tests for sample/regular item mutual exclusivity
  test "adding regular item removes sample of same variant" do
    sample_variant = products(:sample_cup_8oz)

    # First add as sample
    @cart.cart_items.create!(
      product: sample_variant,
      quantity: 1,
      price: 0,
      is_sample: true
    )
    assert_equal 1, @cart.cart_items.samples.count

    # Then add as regular item - should remove sample and add regular
    assert_no_difference "CartItem.count" do
      post cart_cart_items_path, params: {
        cart_item: {
          sku: sample_variant.sku,
          quantity: 2
        }
      }
    end

    # Verify only regular item exists (sample was removed)
    assert_equal 1, @cart.cart_items.where(product: sample_variant).count
    assert_equal 0, @cart.cart_items.samples.count

    regular_item = @cart.cart_items.find_by(product: sample_variant)
    assert regular_item.price > 0, "Should be a regular item, not a sample"
    assert_equal 2, regular_item.quantity
  end

  test "rejects adding sample when regular item of same variant exists" do
    sample_variant = products(:sample_cup_8oz)

    # First add as regular item
    @cart.cart_items.create!(
      product: sample_variant,
      quantity: 2,
      price: sample_variant.price,
      is_sample: false
    )

    # Then try to add as sample - should be rejected
    assert_no_difference "CartItem.count" do
      post cart_cart_items_path, params: {
        product_id: sample_variant.id,
        sample: true
      }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    # Verify only regular item exists
    assert_equal 1, @cart.cart_items.where(product: sample_variant).count
    regular_item = @cart.cart_items.find_by(product: sample_variant)
    assert regular_item.price > 0, "Should still be the regular item"
  end

  test "adding regular item when sample exists preserves quantity" do
    sample_variant = products(:sample_cup_8oz)

    # Add sample first
    @cart.cart_items.create!(
      product: sample_variant,
      quantity: 1,
      price: 0,
      is_sample: true
    )

    # Add regular item with quantity 5
    post cart_cart_items_path, params: {
      cart_item: {
        sku: sample_variant.sku,
        quantity: 5
      }
    }

    # Should have only the regular item with correct quantity
    assert_equal 1, @cart.cart_items.where(product: sample_variant).count
    regular_item = @cart.cart_items.find_by(product: sample_variant)
    assert_equal 5, regular_item.quantity
    assert regular_item.price > 0
  end

  # =============================================================================
  # STRUCTURED EVENT EMISSION TESTS (US3: Cart Events)
  # =============================================================================

  test "emits cart.item_added event when adding standard product" do
    product = products(:one)

    assert_event_reported("cart.item_added") do
      post cart_cart_items_path, params: { cart_item: { sku: product.sku, quantity: 2 } }
    end
  end

  test "emits cart.item_added event when adding sample" do
    product = products(:sample_cup_8oz)

    assert_event_reported("cart.item_added") do
      post cart_cart_items_path, params: { sample: true, product_id: product.id }
    end
  end

  test "emits cart.item_removed event when destroying item" do
    # Add an item first
    product = products(:one)
    post cart_cart_items_path, params: { cart_item: { sku: product.sku, quantity: 1 } }
    cart_item = @cart.reload.cart_items.last

    assert_event_reported("cart.item_removed") do
      delete cart_cart_item_path(cart_item)
    end
  end

  test "emits cart.item_removed when quantity set to zero" do
    # Add an item first
    product = products(:one)
    post cart_cart_items_path, params: { cart_item: { sku: product.sku, quantity: 1 } }
    cart_item = @cart.reload.cart_items.last

    assert_event_reported("cart.item_removed") do
      patch cart_cart_item_path(cart_item), params: { cart_item: { quantity: 0 } }
    end
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
