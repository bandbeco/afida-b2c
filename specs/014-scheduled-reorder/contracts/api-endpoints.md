# API Contracts: Scheduled Reorder with Review

**Feature**: 014-scheduled-reorder
**Date**: 2025-12-16

## Routes Overview

```ruby
# config/routes.rb additions

resources :reorder_schedules, path: "reorder-schedules" do
  member do
    patch :pause
    patch :resume
    patch :skip_next
  end
  collection do
    get :setup           # Start setup flow (from order)
    get :setup_success   # Stripe redirect after payment method saved
    get :setup_cancel    # Stripe redirect on cancel
  end
end

resources :pending_orders, path: "pending-orders", only: [:edit, :update] do
  member do
    post :confirm        # One-click confirmation
  end
end
```

---

## ReorderSchedules Endpoints

### GET /reorder-schedules

**Description**: List all reorder schedules for current user.

**Authentication**: Required

**Response** (200 OK):
```
Renders: app/views/reorder_schedules/index.html.erb
```

**Controller Logic**:
```ruby
def index
  @schedules = Current.user.reorder_schedules
                       .includes(reorder_schedule_items: { product_variant: :product })
                       .order(created_at: :desc)
end
```

---

### GET /reorder-schedules/:id

**Description**: Show single reorder schedule with items and history.

**Authentication**: Required (must own schedule)

**Response** (200 OK):
```
Renders: app/views/reorder_schedules/show.html.erb
```

**Response** (404 Not Found): Schedule not found or not owned by user

---

### GET /reorder-schedules/setup?order_id=:id

**Description**: Start reorder schedule setup flow from an order.

**Authentication**: Required

**Query Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| order_id | integer | Yes | Source order ID |

**Response** (200 OK):
```
Renders: app/views/reorder_schedules/new.html.erb
```

Shows frequency selection form with items from source order.

**Response** (404 Not Found): Order not found or not owned by user

**Response** (422 Unprocessable Entity): Order has no reorderable items

---

### POST /reorder-schedules

**Description**: Create reorder schedule and redirect to Stripe Setup for payment method.

**Authentication**: Required

**Request Body** (form data):
```
reorder_schedule[order_id]=123
reorder_schedule[frequency]=monthly
```

**Response** (303 See Other):
- Redirects to Stripe Checkout (setup mode) to save payment method
- On success, Stripe redirects to `/reorder-schedules/setup-success?session_id=xxx`

**Response** (422 Unprocessable Entity): Validation errors

---

### GET /reorder-schedules/setup-success?session_id=:id

**Description**: Complete schedule setup after Stripe payment method saved.

**Authentication**: Required

**Query Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| session_id | string | Yes | Stripe Checkout Session ID |

**Response** (303 See Other):
- Creates ReorderSchedule and ReorderScheduleItems
- Redirects to `/reorder-schedules/:id` with success flash

**Response** (422 Unprocessable Entity): Invalid session or setup failed

---

### GET /reorder-schedules/:id/edit

**Description**: Edit schedule items and frequency.

**Authentication**: Required (must own schedule)

**Response** (200 OK):
```
Renders: app/views/reorder_schedules/edit.html.erb
```

---

### PATCH /reorder-schedules/:id

**Description**: Update schedule frequency or items.

**Authentication**: Required (must own schedule)

**Request Body** (form data):
```
reorder_schedule[frequency]=every_two_weeks
reorder_schedule[reorder_schedule_items_attributes][0][id]=1
reorder_schedule[reorder_schedule_items_attributes][0][quantity]=3
reorder_schedule[reorder_schedule_items_attributes][1][id]=2
reorder_schedule[reorder_schedule_items_attributes][1][_destroy]=true
```

**Response** (303 See Other): Redirects to show page with success flash

**Response** (422 Unprocessable Entity): Validation errors

---

### PATCH /reorder-schedules/:id/pause

**Description**: Pause an active schedule.

**Authentication**: Required (must own schedule)

**Response** (303 See Other): Redirects to show page with success flash

**Response** (422 Unprocessable Entity): Schedule not active

---

### PATCH /reorder-schedules/:id/resume

**Description**: Resume a paused schedule.

**Authentication**: Required (must own schedule)

**Response** (303 See Other): Redirects to show page with success flash

**Response** (422 Unprocessable Entity): Schedule not paused

---

### PATCH /reorder-schedules/:id/skip_next

**Description**: Skip the next scheduled delivery.

**Authentication**: Required (must own schedule)

**Response** (303 See Other):
- Cancels any pending order for this schedule
- Advances next_scheduled_date by one interval
- Redirects to show page with success flash

**Response** (422 Unprocessable Entity): No upcoming delivery to skip

---

### DELETE /reorder-schedules/:id

**Description**: Cancel a reorder schedule.

**Authentication**: Required (must own schedule)

**Response** (303 See Other): Redirects to index page with success flash

---

## PendingOrders Endpoints

### GET /pending-orders/:id/edit?token=:token

**Description**: Edit a pending order before confirmation.

**Authentication**: Via signed token (from email link)

**Query Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| token | string | Yes | Signed token from email |

**Response** (200 OK):
```
Renders: app/views/pending_orders/edit.html.erb
```

Shows editable items with current prices and totals.

**Response** (404 Not Found): Invalid or expired token

**Response** (410 Gone): Pending order already confirmed or expired

---

### PATCH /pending-orders/:id?token=:token

**Description**: Update pending order items before confirmation.

**Authentication**: Via signed token

**Request Body** (form data):
```
pending_order[items][0][product_variant_id]=123
pending_order[items][0][quantity]=2
pending_order[items][1][product_variant_id]=456
pending_order[items][1][quantity]=1
```

**Response** (303 See Other): Redirects to edit page with updated totals

**Response** (404 Not Found): Invalid or expired token

**Response** (422 Unprocessable Entity): Validation errors (empty items, invalid quantities)

---

### POST /pending-orders/:id/confirm?token=:token

**Description**: Confirm pending order and charge payment method.

**Authentication**: Via signed token (from email "Confirm Order" button)

**Query Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| token | string | Yes | Signed token from email |

**Response** (303 See Other):
- Charges saved payment method via Stripe PaymentIntent
- Creates Order and OrderItems from pending order snapshot
- Marks pending order as confirmed
- Advances schedule to next date
- Sends order confirmation email
- Redirects to order confirmation page

**Response** (404 Not Found): Invalid or expired token

**Response** (410 Gone): Pending order already confirmed or expired

**Response** (422 Unprocessable Entity): Payment failed
- Redirects to payment failure page with instructions to update payment method

---

## Email Links

### Confirm Order (one-click)

**URL Format**:
```
https://example.com/pending-orders/:id/confirm?token=:signed_token
```

**Token Generation**:
```ruby
pending_order.to_sgid(expires_in: 7.days, for: "pending_order_confirm").to_s
```

### Edit Order

**URL Format**:
```
https://example.com/pending-orders/:id/edit?token=:signed_token
```

**Token Generation**:
```ruby
pending_order.to_sgid(expires_in: 7.days, for: "pending_order_edit").to_s
```

---

## Error Responses

All endpoints return standard Rails error responses:

### 401 Unauthorized
```
Redirects to: /signin
Flash: "Please sign in to access this page"
```

### 403 Forbidden
```
Redirects to: /reorder-schedules
Flash: "You don't have permission to access this schedule"
```

### 404 Not Found
```
Redirects to: /reorder-schedules
Flash: "Schedule not found"
```

### 410 Gone (for pending orders)
```
Renders: error page
Message: "This order has already been processed or has expired"
```

### 422 Unprocessable Entity
```
Re-renders: form with errors
@resource.errors displayed
```

---

## Turbo Responses

All form submissions support Turbo for seamless UX:

```ruby
# Controller pattern
def update
  if @schedule.update(schedule_params)
    redirect_to @schedule, notice: "Schedule updated"
  else
    render :edit, status: :unprocessable_entity
  end
end
```

Turbo Stream responses for inline updates:
```ruby
# Pause action with Turbo Stream
def pause
  @schedule.pause!
  respond_to do |format|
    format.turbo_stream { render turbo_stream: turbo_stream.replace(@schedule) }
    format.html { redirect_to @schedule, notice: "Schedule paused" }
  end
end
```
