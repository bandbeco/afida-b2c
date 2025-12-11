# feat: Dedicated Order Confirmation Page

## Overview

Create a dedicated order confirmation page (`/orders/:id/confirmation`) separate from the order details page (`/orders/:id`) to:

1. **Fix GA4 duplicate purchase events** - Currently fires on every order show page view
2. **Enable different UX** - Celebratory "thank you" vs utilitarian order reference

## Problem Statement

The current `orders/show` page serves two conflicting purposes:

| Purpose | "Just Bought" | "Viewing Past Order" |
|---------|--------------|---------------------|
| **Tone** | Celebratory | Utilitarian |
| **GA4 Event** | Fire `purchase` | Do NOT fire |
| **Access** | Immediate post-checkout | Anytime from history |

**Current Bug:** GA4 `purchase` event fires every time `/orders/:id` is viewed, causing:
- Inflated revenue in GA4
- Duplicate conversion attribution
- Incorrect ROAS calculations

## Proposed Solution

### Route Structure

| Route | Purpose | GA4 Event | Access |
|-------|---------|-----------|--------|
| `GET /orders/:id/confirmation` | Post-purchase celebration | `purchase` (once only) | Token-based (always) |
| `GET /orders/:id` | Order reference/history | None | Owner or token |

### Key Design Decisions (Addressing Review Feedback)

1. **Token-based access everywhere** - No time-based window. Simpler, more secure.
2. **Atomic GA4 tracking** - Database-level atomic update prevents race conditions.
3. **Signed IDs** - Use Rails built-in `to_sgid` instead of custom token generation.
4. **Session-based ownership** - Store order ID in session after creation for immediate access.
5. **Single authorization method** - One method for both pages, reduces complexity.

### User Flows

```
Guest Checkout:
Cart → Stripe → /checkout/success
              → stores order.id in session
              → redirects to /orders/:id/confirmation?token=xxx (GA4 fires once)
              → Email link → /orders/:id?token=xxx (no GA4)

Authenticated Checkout:
Cart → Stripe → /checkout/success → /orders/:id/confirmation (GA4 fires once)
              → Order History → /orders/:id (no GA4)

Page Refresh:
/orders/:id/confirmation → Refresh → Same page (GA4 does NOT fire - atomic check)
```

## Technical Approach

### Database Migration

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_ga4_tracking_to_orders.rb
class AddGa4TrackingToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :ga4_purchase_tracked_at, :datetime
  end
end
```

### Routes

```ruby
# config/routes.rb
resources :orders, only: [:show, :index] do
  member do
    get :confirmation
  end
end
```

### Controller Changes

#### OrdersController (Simplified)

```ruby
# app/controllers/orders_controller.rb
class OrdersController < ApplicationController
  allow_unauthenticated_access only: [:show, :confirmation]
  before_action :require_authentication, only: [:index]
  before_action :resume_session, only: [:show, :confirmation]
  before_action :set_order, only: [:show, :confirmation]
  before_action :authorize_order_access!, only: [:show, :confirmation]

  def confirmation
    # Atomic GA4 tracking - prevents race condition on concurrent requests
    @should_track_ga4 = @order.mark_ga4_tracked!
  end

  def show
    # Existing implementation unchanged
  end

  def index
    @orders = Current.user.orders.recent.includes(:order_items)
  end

  private

  def set_order
    @order = Order.includes(order_items: { product_variant: :product }).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Order not found"
  end

  # Single authorization method for both actions
  def authorize_order_access!
    return if owns_order?
    return if session_owns_order?
    return if valid_token_access?

    redirect_to root_path, alert: "Order not found"
  end

  def owns_order?
    Current.user && @order.user_id == Current.user.id
  end

  # Session proves THIS user just created THIS order (secure)
  def session_owns_order?
    session[:recent_order_id] == @order.id
  end

  def valid_token_access?
    return false unless params[:token].present?

    # Use Rails signed global ID for verification
    located_order = GlobalID::Locator.locate_signed(params[:token], for: 'order_access')
    located_order == @order
  rescue ActiveRecord::RecordNotFound, ActiveSupport::MessageVerifier::InvalidSignature
    false
  end
end
```

#### CheckoutsController

```ruby
# app/controllers/checkouts_controller.rb

def success
  # ... existing order creation logic ...

  # Store in session for immediate access (proves ownership)
  session[:recent_order_id] = order.id

  # Redirect to confirmation with signed token
  redirect_to order_confirmation_path(order, token: order.signed_access_token),
              status: :see_other
end
```

### Model Changes

```ruby
# app/models/order.rb
class Order < ApplicationRecord
  # ... existing code ...

  # Generate signed access token using Rails built-in
  def signed_access_token
    to_sgid(expires_in: 30.days, for: 'order_access').to_s
  end

  # Atomic GA4 tracking - returns true if THIS call set the timestamp
  # Prevents race condition when multiple requests hit simultaneously
  def mark_ga4_tracked!
    Order.where(id: id, ga4_purchase_tracked_at: nil)
         .update_all(ga4_purchase_tracked_at: Time.current) > 0
  end

  def ga4_tracked?
    ga4_purchase_tracked_at.present?
  end
end
```

### View: Confirmation Page

```erb
<%# app/views/orders/confirmation.html.erb %>

<%# GA4 E-commerce: purchase event - fires ONCE per order (atomic) %>
<% if @should_track_ga4 %>
  <% content_for :head do %>
    <script>
      <%= ecommerce_purchase_event(@order) %>
    </script>
  <% end %>
<% end %>

<div class="container mx-auto px-4 py-8">
  <div class="max-w-4xl mx-auto">

    <%# Celebratory Header %>
    <div class="bg-green-50 border border-green-200 rounded-lg p-8 mb-8 text-center">
      <svg class="h-16 w-16 text-green-500 mx-auto mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
      <h1 class="text-3xl font-bold text-green-800 mb-2">Thank You for Your Order!</h1>
      <p class="text-green-600 text-lg">Order <%= @order.display_number %> has been confirmed</p>
      <p class="text-green-600 mt-2">A confirmation email has been sent to <strong><%= @order.email %></strong></p>
    </div>

    <%# What Happens Next %>
    <div class="bg-white shadow-lg rounded-lg overflow-hidden mb-8">
      <div class="px-6 py-4 bg-gray-50 border-b">
        <h2 class="text-xl font-semibold text-gray-900">What Happens Next?</h2>
      </div>
      <div class="p-6">
        <ol class="space-y-4">
          <li class="flex items-start">
            <div class="flex-shrink-0 h-8 w-8 rounded-full bg-green-500 flex items-center justify-center text-white font-semibold">✓</div>
            <div class="ml-4">
              <h4 class="font-medium text-gray-900">Order Confirmed</h4>
              <p class="text-gray-600">Your payment has been processed successfully</p>
            </div>
          </li>
          <li class="flex items-start">
            <div class="flex-shrink-0 h-8 w-8 rounded-full bg-gray-200 flex items-center justify-center text-gray-600 font-semibold">2</div>
            <div class="ml-4">
              <h4 class="font-medium text-gray-900">Processing</h4>
              <p class="text-gray-600">We'll prepare your order within 1-2 business days</p>
            </div>
          </li>
          <li class="flex items-start">
            <div class="flex-shrink-0 h-8 w-8 rounded-full bg-gray-200 flex items-center justify-center text-gray-600 font-semibold">3</div>
            <div class="ml-4">
              <h4 class="font-medium text-gray-900">Delivery</h4>
              <p class="text-gray-600">Your order will arrive in 3-5 business days</p>
            </div>
          </li>
        </ol>
      </div>
    </div>

    <%# Order Summary %>
    <%= render "orders/order_summary", order: @order %>

    <%# Shipping Address %>
    <%= render "orders/shipping_address", order: @order %>

    <%# Actions %>
    <div class="flex flex-col sm:flex-row gap-4 justify-center mt-8">
      <%= link_to "Continue Shopping", root_path, class: "btn btn-primary" %>
      <%= link_to "View Order Details", order_details_path_for(@order), class: "btn btn-outline" %>
      <% if authenticated? %>
        <%= link_to "View All Orders", orders_path, class: "btn btn-outline" %>
      <% end %>
    </div>

  </div>
</div>
```

### Helper for Order Links

```ruby
# app/helpers/orders_helper.rb
module OrdersHelper
  def order_details_path_for(order)
    if Current.user && order.user_id == Current.user.id
      order_path(order)
    else
      order_path(order, token: order.signed_access_token)
    end
  end
end
```

### View: Order Show Page (Updated)

```erb
<%# app/views/orders/show.html.erb %>
<%# REMOVED: GA4 purchase event - now only on confirmation page %>

<div class="container mx-auto px-4 py-8">
  <div class="max-w-4xl mx-auto">

    <%# Neutral Header %>
    <div class="mb-8">
      <h1 class="text-2xl font-bold text-gray-900">Order <%= @order.display_number %></h1>
      <p class="text-gray-600">Placed on <%= @order.created_at.strftime("%B %d, %Y at %I:%M %p") %></p>
    </div>

    <%# Rest of existing content unchanged %>

  </div>
</div>
```

### Email Link Format

```erb
<%# app/views/order_mailer/confirmation_email.html.erb %>
<%= link_to "View Your Order", order_url(@order, token: @order.signed_access_token) %>
```

## Acceptance Criteria

### Functional Requirements

- [ ] New route `GET /orders/:id/confirmation` exists and renders confirmation view
- [ ] Checkout success redirects to confirmation page with signed token
- [ ] GA4 `purchase` event fires exactly once per order (atomic database update)
- [ ] GA4 event does NOT fire on page refresh (verified via atomic check)
- [ ] GA4 event does NOT fire on show page visits
- [ ] Confirmation page accessible via signed token or session ownership
- [ ] Show page accessible via signed token or authenticated ownership
- [ ] Email confirmation links to show page with signed token

### Security Requirements

- [ ] No user can access another user's order without valid token
- [ ] Session-based access only works for the session that created the order
- [ ] Signed tokens are tamper-proof and expire after 30 days

### Non-Functional Requirements

- [ ] No N+1 queries on confirmation or show pages
- [ ] GA4 event data matches existing schema

## Files to Create/Modify

### Create

| File | Purpose |
|------|---------|
| `db/migrate/YYYYMMDDHHMMSS_add_ga4_tracking_to_orders.rb` | Add tracking column |
| `app/views/orders/confirmation.html.erb` | New confirmation page view |
| `app/views/orders/_order_summary.html.erb` | Shared partial |
| `app/views/orders/_shipping_address.html.erb` | Shared partial |
| `test/controllers/orders_controller_confirmation_test.rb` | Controller tests |
| `test/system/order_confirmation_flow_test.rb` | End-to-end flow test |

### Modify

| File | Changes |
|------|---------|
| `config/routes.rb` | Add `confirmation` member route |
| `app/controllers/orders_controller.rb` | Add `confirmation` action, simplify auth |
| `app/controllers/checkouts_controller.rb` | Redirect to confirmation, set session |
| `app/models/order.rb` | Add `mark_ga4_tracked!`, `signed_access_token` |
| `app/helpers/orders_helper.rb` | Add `order_details_path_for` |
| `app/views/orders/show.html.erb` | Remove GA4 tracking |
| `app/views/order_mailer/confirmation_email.html.erb` | Use signed token |

## Implementation Phases

### Phase 1: Core Infrastructure (~1 hour)
1. Create migration for `ga4_purchase_tracked_at`
2. Add `mark_ga4_tracked!` and `signed_access_token` to Order model
3. Add route for confirmation page
4. Add `confirmation` action to controller

### Phase 2: Authorization & Access (~30 min)
5. Implement unified `authorize_order_access!` method
6. Add session-based ownership in CheckoutsController
7. Update redirect to use confirmation path with token

### Phase 3: Views (~30 min)
8. Create confirmation view with celebratory header
9. Extract shared partials for order summary and shipping
10. Remove GA4 from show page
11. Update email template

### Phase 4: Testing (~1 hour)
12. Controller tests for authorization (all paths)
13. System test for GA4 deduplication
14. Manual QA with GA4 DebugView

## Changes from Original Plan (Review Feedback)

| Issue | Original | Revised |
|-------|----------|---------|
| **Security** | Time-based access allowed any order <10min old | Session + token only |
| **Race condition** | Check-then-act pattern | Atomic `update_all` |
| **Token generation** | Custom SHA256 hash | Rails `to_sgid` |
| **Authorization** | 7 methods | 1 method (`authorize_order_access!`) |
| **Flash notice** | "Viewing order details" on redirect | Removed (silent redirect) |
| **View logic** | Inline conditional for token | Helper method |

## References

### Internal Files
- `app/controllers/checkouts_controller.rb:139` - Current redirect target
- `app/views/orders/show.html.erb:1-6` - Current GA4 implementation
- `app/helpers/analytics_helper.rb:191-209` - `ecommerce_purchase_event` method

### External Documentation
- [GA4 E-commerce Implementation](https://developers.google.com/analytics/devguides/collection/ga4/ecommerce)
- [Rails Signed Global IDs](https://github.com/rails/globalid#signed-global-ids)
- [Stripe Checkout Success Handling](https://stripe.com/docs/payments/checkout/fulfill-orders)
