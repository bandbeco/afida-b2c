# API Contract: Address Management

**Feature**: 001-user-address-storage
**Base Path**: `/account/addresses`
**Authentication**: Required (session-based)

## Overview

RESTful endpoints for managing user delivery addresses. All endpoints require authentication and scope access to the current user's addresses only.

---

## Endpoints

### List Addresses

**GET** `/account/addresses`

Returns all addresses for the current user, default address first.

#### Request

```http
GET /account/addresses HTTP/1.1
Accept: text/html
```

#### Response

**200 OK** - HTML page with address list

```html
<!-- Rendered: account/addresses/index.html.erb -->
<!-- Contains: list of address cards with edit/delete/set-default actions -->
```

---

### New Address Form

**GET** `/account/addresses/new`

Displays form to create a new address.

#### Request

```http
GET /account/addresses/new HTTP/1.1
Accept: text/html
```

#### Response

**200 OK** - HTML form

---

### Create Address

**POST** `/account/addresses`

Creates a new address for the current user.

#### Request

```http
POST /account/addresses HTTP/1.1
Content-Type: application/x-www-form-urlencoded
Accept: text/html

address[nickname]=Office&
address[recipient_name]=John+Smith&
address[company_name]=Acme+Ltd&
address[line1]=123+High+Street&
address[line2]=Unit+4&
address[city]=London&
address[postcode]=SW1A+1AA&
address[phone]=07700900123&
address[default]=1
```

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| address[nickname] | string | Yes | User-friendly name (e.g., "Office") |
| address[recipient_name] | string | Yes | Recipient's full name |
| address[company_name] | string | No | Business name |
| address[line1] | string | Yes | Street address |
| address[line2] | string | No | Additional address info |
| address[city] | string | Yes | City/town |
| address[postcode] | string | Yes | UK postcode |
| address[phone] | string | No | Contact phone number |
| address[default] | boolean | No | Set as default address |

#### Responses

**303 See Other** - Redirect to address list on success

```http
HTTP/1.1 303 See Other
Location: /account/addresses
```

**422 Unprocessable Entity** - Validation errors

```html
<!-- Re-renders form with error messages -->
```

---

### Edit Address Form

**GET** `/account/addresses/:id/edit`

Displays form to edit an existing address.

#### Request

```http
GET /account/addresses/123/edit HTTP/1.1
Accept: text/html
```

#### Response

**200 OK** - HTML form with current values

**404 Not Found** - Address not found or not owned by user

---

### Update Address

**PATCH** `/account/addresses/:id`

Updates an existing address.

#### Request

```http
PATCH /account/addresses/123 HTTP/1.1
Content-Type: application/x-www-form-urlencoded
Accept: text/html

address[nickname]=Main+Office&
address[recipient_name]=John+Smith
```

#### Responses

**303 See Other** - Redirect to address list on success

**422 Unprocessable Entity** - Validation errors

**404 Not Found** - Address not found or not owned by user

---

### Delete Address

**DELETE** `/account/addresses/:id`

Deletes an address. If deleted address was default, oldest remaining becomes default.

#### Request

```http
DELETE /account/addresses/123 HTTP/1.1
Accept: text/html
```

#### Responses

**303 See Other** - Redirect to address list

**404 Not Found** - Address not found or not owned by user

---

### Set Default Address

**PATCH** `/account/addresses/:id/set_default`

Sets an address as the user's default. Unsets any previous default.

#### Request

```http
PATCH /account/addresses/123/set_default HTTP/1.1
Accept: text/html
```

#### Responses

**303 See Other** - Redirect to address list

**404 Not Found** - Address not found or not owned by user

---

### Create From Order

**POST** `/account/addresses/create_from_order`

Creates a new address from a completed order's shipping details.

#### Request

```http
POST /account/addresses/create_from_order HTTP/1.1
Content-Type: application/x-www-form-urlencoded
Accept: text/html

order_id=456&
nickname=New+Office
```

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| order_id | integer | Yes | ID of the order to copy address from |
| nickname | string | Yes | User-friendly name for the address |

#### Validations

- Order must belong to current user
- Order must exist

#### Responses

**303 See Other** - Redirect to order confirmation

**422 Unprocessable Entity** - Validation errors or order not owned by user

---

## Checkout Integration

### Checkout with Address Selection

**POST** `/checkout`

Modified to accept optional address_id parameter.

#### Request (with saved address)

```http
POST /checkout HTTP/1.1
Content-Type: application/x-www-form-urlencoded

address_id=123
```

#### Request (enter new address)

```http
POST /checkout HTTP/1.1
Content-Type: application/x-www-form-urlencoded

address_id=
```

#### Behavior

| address_id | Result |
|------------|--------|
| Present and valid | Stripe Checkout created with prefilled address |
| Empty or missing | Stripe Checkout created with empty address form |
| Invalid (not user's) | Ignored, empty address form |

---

## Turbo Stream Responses

For Turbo-enabled requests, endpoints return Turbo Stream responses for partial page updates:

### Create Success

```html
<turbo-stream action="prepend" target="addresses">
  <template>
    <!-- Rendered _address.html.erb partial -->
  </template>
</turbo-stream>
<turbo-stream action="remove" target="new_address_form">
</turbo-stream>
```

### Delete Success

```html
<turbo-stream action="remove" target="address_123">
</turbo-stream>
```

### Set Default Success

```html
<turbo-stream action="replace" target="address_123">
  <template>
    <!-- Updated card with DEFAULT badge -->
  </template>
</turbo-stream>
<turbo-stream action="replace" target="address_456">
  <template>
    <!-- Previous default, now without badge -->
  </template>
</turbo-stream>
```

---

## Error Handling

| HTTP Status | Condition | Response |
|-------------|-----------|----------|
| 401 Unauthorized | Not logged in | Redirect to login |
| 404 Not Found | Address not found or not owned by user | Error page |
| 422 Unprocessable Entity | Validation failed | Re-render form with errors |
| 429 Too Many Requests | Rate limited | Error message |

---

## Security Considerations

1. **Scoped Access**: All queries filtered by `Current.user.addresses`
2. **CSRF Protection**: All mutating requests require valid CSRF token
3. **Parameter Filtering**: Strong parameters whitelist only allowed attributes
4. **No Enumeration**: 404 returned for both "not found" and "not owned" to prevent ID enumeration
