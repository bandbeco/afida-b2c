# Quickstart: Order User Association

**Feature**: 009-order-user-association
**Date**: 2025-11-26

## Overview

This feature fixes a security vulnerability where any authenticated user can view any order. The fix is minimal - just authorization logic in the controller.

## What's Already Done (No Changes Needed)

1. **Database association**: `Order belongs_to :user, optional: true` ✅
2. **Checkout association**: Orders linked to logged-in users at payment ✅
3. **Order index**: Already scoped to `Current.user.orders` ✅
4. **Views**: Order list and detail views exist with empty state ✅

## What Needs Implementation

### Single Change: Authorization in OrdersController

**File**: `app/controllers/orders_controller.rb`

**Current (vulnerable)**:
```ruby
def set_order
  @order = Order.includes(order_items: :product_variant).find(params[:id])
end
```

**Required (secure)**:
```ruby
def set_order
  @order = Current.user.orders.includes(order_items: :product_variant).find(params[:id])
rescue ActiveRecord::RecordNotFound
  redirect_to orders_path, alert: "Order not found"
end
```

## TDD Implementation Order

Per constitution requirements, write tests FIRST:

### Step 1: Write Failing Tests

```ruby
# test/controllers/orders_controller_test.rb

test "show redirects when accessing another user's order" do
  other_user = users(:other)
  other_order = orders(:other_user_order)

  sign_in users(:customer)
  get order_path(other_order)

  assert_redirected_to orders_path
  assert_equal "Order not found", flash[:alert]
end

test "show displays own order" do
  user = users(:customer)
  order = orders(:customer_order)

  sign_in user
  get order_path(order)

  assert_response :success
end
```

### Step 2: Run Tests (Should Fail)

```bash
rails test test/controllers/orders_controller_test.rb
```

### Step 3: Implement Fix

Update `set_order` method as shown above.

### Step 4: Run Tests (Should Pass)

```bash
rails test test/controllers/orders_controller_test.rb
```

### Step 5: Run Full Test Suite + Linter

```bash
rails test
rubocop
brakeman
```

## Verification Checklist

- [ ] Tests written before implementation
- [ ] Tests fail initially (red phase)
- [ ] Implementation makes tests pass (green phase)
- [ ] All existing tests still pass
- [ ] RuboCop passes
- [ ] Brakeman security scan passes
- [ ] Manual verification: Cannot access other user's order
- [ ] Manual verification: Can access own orders

## Routes Reference

```
GET /orders         -> OrdersController#index   (order list)
GET /orders/:id     -> OrdersController#show    (order details)
```

## Test Fixtures Needed

Ensure test fixtures include:
- User with orders (`users(:customer)`, `orders(:customer_order)`)
- Different user with orders (`users(:other)`, `orders(:other_user_order)`)
- Guest order (order with `user_id: nil`) for edge case testing

## Time Estimate

- Tests: ~30 minutes
- Implementation: ~15 minutes
- Verification: ~15 minutes
- **Total: ~1 hour**
