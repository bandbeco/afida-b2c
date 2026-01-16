# API Contract: Email Subscriptions

**Feature**: 001-email-signup-discount
**Date**: 2026-01-16

## Endpoints

### POST /email_subscriptions

Create a new email subscription and claim the discount.

#### Request

**Content-Type**: `application/x-www-form-urlencoded` (standard Rails form)

**CSRF**: Required (Rails authenticity token)

**Parameters**:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `email` | string | Yes | Visitor's email address |

**Example Request** (Turbo form submission):

```html
<form action="/email_subscriptions" method="post" data-turbo="true">
  <input type="hidden" name="authenticity_token" value="[token]">
  <input type="email" name="email" required>
  <button type="submit">Get 5% off</button>
</form>
```

#### Responses

**Success (200 OK)** - Turbo Stream

Returned when email is eligible and subscription is created.

```html
<turbo-stream action="replace" target="discount-signup">
  <template>
    <!-- Success partial with savings amount -->
  </template>
</turbo-stream>
```

Session side effect: `session[:discount_code] = "WELCOME5"`

---

**Already Claimed (200 OK)** - Turbo Stream

Returned when email already exists in `email_subscriptions` table.

```html
<turbo-stream action="replace" target="discount-signup">
  <template>
    <!-- Already claimed partial -->
  </template>
</turbo-stream>
```

---

**Not Eligible (200 OK)** - Turbo Stream

Returned when email has previous orders in `orders` table.

```html
<turbo-stream action="replace" target="discount-signup">
  <template>
    <!-- Not eligible partial -->
  </template>
</turbo-stream>
```

---

**Validation Error (422 Unprocessable Entity)** - Turbo Stream

Returned when email format is invalid.

```html
<turbo-stream action="replace" target="discount-signup">
  <template>
    <!-- Form with error message -->
  </template>
</turbo-stream>
```

## Checkout Integration

### Existing POST /checkout (Modified)

The checkout endpoint is modified to apply the discount coupon if present in session.

#### Session Check

```ruby
if session[:discount_code].present?
  session_params[:discounts] = [{ coupon: session[:discount_code] }]
end
```

#### Session Cleanup

After successful order creation in `GET /checkout/success`:

```ruby
session.delete(:discount_code)
```

## View Contract

### Cart Page Component

**Location**: `app/views/carts/show.html.erb`

**Partial**: `email_subscriptions/cart_signup_form`

**Turbo Frame ID**: `discount-signup`

**Visibility Logic**:

```ruby
# Show form if:
# 1. User is not logged in, OR
# 2. User is logged in but has no orders
def show_discount_signup?
  return true unless Current.user
  !Current.user.orders.exists?
end
```

### Form States

| State | Partial | Trigger |
|-------|---------|---------|
| Default | `_cart_signup_form.html.erb` | Initial page load (eligible) |
| Success | `_success.html.erb` | Successful form submission |
| Already Claimed | `_already_claimed.html.erb` | Email already subscribed |
| Not Eligible | `_not_eligible.html.erb` | Email has previous orders |
| Hidden | (no render) | Logged-in user with orders |
