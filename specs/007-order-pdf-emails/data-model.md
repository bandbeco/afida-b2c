# Data Model: Order Summary PDF Attachment

**Feature**: 007-order-pdf-emails
**Date**: 2025-11-25

## Overview

This feature requires **NO schema changes**. It leverages existing Order and OrderItem models to generate PDFs on-demand.

## Existing Models (No Changes Required)

### Order Model

**Table**: `orders`
**Purpose**: Stores completed customer orders

**Relevant attributes for PDF generation**:
- `order_number` (string) - Unique order identifier (e.g., "ORD-2025-001234")
- `email` (string) - Customer email address
- `created_at` (datetime) - Order date
- `subtotal_amount` (decimal) - Order subtotal before VAT and shipping
- `vat_amount` (decimal) - VAT amount (20% in UK)
- `shipping_amount` (decimal) - Shipping cost
- `total_amount` (decimal) - Grand total
- `shipping_name` (string) - Customer name for shipping
- `shipping_address_line1` (string) - Address line 1
- `shipping_address_line2` (string) - Address line 2 (optional)
- `shipping_city` (string) - City
- `shipping_postal_code` (string) - Postal code
- `shipping_country` (string) - Country code (e.g., "GB")

**Associations**:
- `has_many :order_items` - Line items in the order
- `belongs_to :user` (optional) - Associated user if logged in

**Methods used**:
- `order_number` - For filename and display
- `full_shipping_address` - Pre-formatted address string
- `display_number` - Returns "#ORD-2025-001234" format

---

### OrderItem Model

**Table**: `order_items`
**Purpose**: Individual line items within an order

**Relevant attributes for PDF generation**:
- `product_name` (string) - Name of product at purchase time
- `variant_sku` (string) - Product SKU/variant identifier
- `quantity` (integer) - Quantity ordered
- `price` (decimal) - Unit price at purchase time
- `total_price` (decimal) - Line total (quantity × price)

**Associations**:
- `belongs_to :order` - Parent order
- `belongs_to :product` (optional) - Original product (may be deleted)

**Methods used**:
- `product_name` - Product name for display
- `quantity` - Quantity ordered
- `price` - Unit price
- `total_price` - Line total

---

## Service Class (New)

### OrderPdfGenerator

**File**: `app/services/order_pdf_generator.rb`
**Purpose**: Generates PDF document from Order data

**Responsibilities**:
1. Initialize with Order instance
2. Generate PDF with branding, order details, and line items
3. Return PDF data as binary string
4. Handle errors gracefully

**Interface**:
```ruby
class OrderPdfGenerator
  def initialize(order)
    @order = order
  end

  def generate
    # Returns PDF as binary string
    # Raises StandardError if generation fails
  end

  private

  def build_header(pdf)
    # Render logo and company name
  end

  def build_order_info(pdf)
    # Render order number, date
  end

  def build_shipping_address(pdf)
    # Render shipping address
  end

  def build_line_items_table(pdf)
    # Render order items table
  end

  def build_totals(pdf)
    # Render subtotal, VAT, shipping, total
  end

  def build_footer(pdf)
    # Render company contact info
  end
end
```

**Dependencies**:
- `prawn` gem for PDF generation
- `prawn/table` for line item table
- `Rails.root.join('app/frontend/images/logo.png')` for logo image

**Error handling**:
- Validates order has required data before generation
- Raises descriptive errors if required data missing
- Caller (mailer/controller) rescues and handles errors

---

## Data Flow

### Email Attachment Flow

```
CheckoutsController#success
  ↓ (creates Order)
OrderMailer.confirmation_email(order: @order)
  ↓ (calls service)
OrderPdfGenerator.new(@order).generate
  ↓ (returns PDF data)
attachments["Order-#{@order.order_number}.pdf"] = pdf_data
  ↓
Email sent with PDF attachment
```

### Admin Preview Flow

```
Admin visits /admin/orders/123
  ↓ (clicks "Preview PDF" button)
GET /admin/orders/123/preview_pdf
  ↓ (calls service)
OrderPdfGenerator.new(@order).generate
  ↓ (returns PDF data)
send_data pdf_data, disposition: 'inline'
  ↓
PDF opens in browser tab
```

---

## Validation Rules

**Before PDF generation**:
- Order must exist
- Order must have order_number
- Order must have at least one order_item
- Order must have shipping address fields populated
- Order must have valid monetary amounts (subtotal, VAT, shipping, total)

**Validation handled by**:
- Existing ActiveRecord validations on Order model
- OrderPdfGenerator checks for required data before generation

---

## No Schema Migrations Required

**Rationale**:
- PDFs generated on-demand from existing data
- No persistent storage of PDFs (Phase 1 decision)
- No tracking of PDF generation events
- Order and OrderItem models already contain all necessary data

**Future consideration** (if caching implemented):
- Could add Active Storage attachment to Order model
- Migration would add `has_one_attached :pdf_receipt` to Order
- Not implemented in Phase 1 (YAGNI principle)

---

## Performance Considerations

**Data loading**:
- Use eager loading in mailer: `Order.includes(:order_items).find(id)`
- Prevents N+1 queries when iterating over order items in PDF
- Order data already loaded in context (CheckoutsController, Admin::OrdersController)

**Memory usage**:
- PDF generation ~10-20MB peak memory per order
- Garbage collected after generation
- Acceptable for synchronous generation

**File size**:
- Logo image compressed (< 50KB)
- Minimal styling (no heavy fonts or graphics)
- Typical order PDF: 100-200KB
- Target: < 500KB for 95% of orders (easily achievable)

---

## Testing Strategy

**Unit tests** (`test/services/order_pdf_generator_test.rb`):
- Test PDF generation succeeds with valid order
- Test PDF contains correct order number
- Test PDF contains all line items
- Test PDF contains correct totals
- Test PDF file size within limits
- Test error raised when order invalid

**Integration tests** (`test/mailers/order_mailer_test.rb`):
- Test email has PDF attachment
- Test attachment filename correct
- Test attachment MIME type correct
- Test email sends even if PDF generation fails

**System tests** (`test/system/admin/order_preview_test.rb`):
- Test admin can click "Preview PDF" button
- Test PDF opens in new tab
- Test PDF contains order data

---

## Summary

**No database changes required** - Feature leverages existing Order/OrderItem schema

**New code**:
- `OrderPdfGenerator` service class (generates PDFs)
- Modification to `OrderMailer#confirmation_email` (adds attachment)
- Modification to `Admin::OrdersController` (adds preview_pdf action)
- Test files for service, mailer, and admin preview

**Data sources**:
- Order model (order details, totals, shipping address)
- OrderItem model (line items with product names, quantities, prices)
- Logo image (app/frontend/images/logo.png)
