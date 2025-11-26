# API Contract: Admin Order PDF Preview

**Feature**: 007-order-pdf-emails
**Date**: 2025-11-25

## Endpoint

**URL**: `GET /admin/orders/:id/preview_pdf`
**Purpose**: Generate and display order PDF for admin preview
**Authentication**: Required (admin access)

---

## Request

### Path Parameters

| Parameter | Type    | Required | Description |
|-----------|---------|----------|-------------|
| `id`      | integer | Yes      | Order ID    |

### Query Parameters

None

### Request Headers

- Standard Rails session/CSRF headers
- Authentication (existing admin authentication mechanism)

### Example Request

```http
GET /admin/orders/123/preview_pdf HTTP/1.1
Host: localhost:3000
Cookie: _session_id=abc123...
```

---

## Response

### Success Response (200 OK)

**Content-Type**: `application/pdf`
**Content-Disposition**: `inline; filename="Order-ORD-2025-001234.pdf"`

**Body**: Binary PDF data

**Headers**:
```http
HTTP/1.1 200 OK
Content-Type: application/pdf
Content-Disposition: inline; filename="Order-ORD-2025-001234.pdf"
Content-Length: 156789
```

**Behavior**: Browser will attempt to display PDF inline (opens in browser). If browser doesn't support inline PDF display, it will download the file.

---

### Error Responses

#### 404 Not Found

Order with specified ID does not exist

**Response**:
```http
HTTP/1.1 404 Not Found
Content-Type: text/html

<html>
  <body>Order not found</body>
</html>
```

#### 401 Unauthorized

User not authenticated or not an admin

**Response**: Redirects to login page (existing Rails authentication behavior)

```http
HTTP/1.1 302 Found
Location: /login
```

#### 500 Internal Server Error

PDF generation failed due to server error

**Response**:
```http
HTTP/1.1 500 Internal Server Error
Content-Type: text/html

<html>
  <body>
    <h1>Something went wrong</h1>
    <p>Unable to generate PDF. Please try again later.</p>
  </body>
</html>
```

**Logging**: Error details logged to Rails logger with order ID and exception message

---

## Controller Implementation

**File**: `app/controllers/admin/orders_controller.rb`

**Method signature**:
```ruby
def preview_pdf
  # Find order
  # Generate PDF
  # Send PDF data with inline disposition
  # Handle errors (404, 500)
end
```

**Implementation outline**:
```ruby
class Admin::OrdersController < ApplicationController
  before_action :set_order, only: [:show, :preview_pdf]

  def preview_pdf
    begin
      pdf_generator = OrderPdfGenerator.new(@order)
      pdf_data = pdf_generator.generate

      send_data pdf_data,
        filename: "Order-#{@order.order_number}.pdf",
        type: 'application/pdf',
        disposition: 'inline'
    rescue StandardError => e
      Rails.logger.error("PDF generation failed for order #{@order.id}: #{e.message}")
      flash[:error] = "Unable to generate PDF. Please try again later."
      redirect_to admin_order_path(@order)
    end
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end
end
```

---

## Route Definition

**File**: `config/routes.rb`

**Addition to admin namespace**:
```ruby
namespace :admin do
  resources :orders do
    member do
      get :preview_pdf
    end
  end
end
```

**Generated route**:
```
preview_pdf_admin_order GET /admin/orders/:id/preview_pdf(.:format) admin/orders#preview_pdf
```

---

## UI Integration

**File**: `app/views/admin/orders/show.html.erb`

**Button placement**: Add button to order header section (near Edit/Back buttons)

**HTML**:
```erb
<div class="order-actions">
  <%= link_to "Preview PDF",
      preview_pdf_admin_order_path(@order),
      target: "_blank",
      class: "btn btn-secondary" %>

  <%= link_to "Edit", edit_admin_order_path(@order), class: "btn btn-primary" %>
  <%= link_to "Back", admin_orders_path, class: "btn btn-outline" %>
</div>
```

**Behavior**:
- Opens PDF in new browser tab (`target="_blank"`)
- Button styled consistently with existing admin buttons
- Positioned with other order actions

---

## Security Considerations

**Authentication**: Endpoint requires admin authentication (existing mechanism)
**Authorization**: Admin-only access enforced by controller namespace
**Input validation**: Order ID validated by ActiveRecord (raises 404 if not found)
**Error handling**: PDF generation errors logged but don't expose sensitive data
**CSRF**: GET request (safe method), no CSRF token required

---

## Performance Characteristics

**Response time**: ~1-3 seconds (includes PDF generation)
**Timeout**: Standard Rails request timeout (60 seconds)
**Caching**: No caching (always generates fresh PDF)
**Concurrent requests**: Each request generates PDF independently

**Resource usage per request**:
- CPU: Moderate (PDF rendering)
- Memory: ~10-20MB (PDF generation)
- Disk I/O: Minimal (logo image read)

---

## Testing

**Integration tests** (`test/controllers/admin/orders_controller_test.rb`):
```ruby
test "should preview pdf for existing order" do
  order = orders(:one)
  get preview_pdf_admin_order_path(order)

  assert_response :success
  assert_equal 'application/pdf', response.content_type
  assert_match /Order-#{order.order_number}.pdf/, response.headers['Content-Disposition']
end

test "should return 404 for non-existent order" do
  get preview_pdf_admin_order_path(id: 999999)
  assert_response :not_found
end

test "should require admin authentication" do
  # Test with unauthenticated user
  # Assert redirects to login
end
```

**System tests** (`test/system/admin/order_preview_test.rb`):
```ruby
test "admin can preview order pdf" do
  # Login as admin
  # Visit order show page
  # Click "Preview PDF" button
  # Assert new tab opens with PDF
end
```

---

## Future Enhancements (Not in Phase 1)

1. **Download option**: Add separate "Download PDF" button with `disposition: 'attachment'`
2. **Email resend**: Add "Resend confirmation email" button to trigger email with PDF
3. **PDF caching**: Cache generated PDFs with Active Storage for faster subsequent access
4. **Bulk download**: Generate ZIP of multiple order PDFs
5. **Custom templates**: Allow different PDF templates for different order types

---

## Summary

**Endpoint**: `GET /admin/orders/:id/preview_pdf`
**Purpose**: Admin preview of order PDF
**Response**: Binary PDF data with inline disposition
**Authentication**: Admin-only (existing mechanism)
**Performance**: 1-3 seconds generation time
**Error handling**: Graceful degradation with user-friendly error messages
