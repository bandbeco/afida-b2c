# Email Contract: Order Confirmation with PDF Attachment

**Feature**: 007-order-pdf-emails
**Date**: 2025-11-25

## Overview

This document describes the contract for order confirmation emails with PDF attachments sent to customers after completing a purchase.

---

## Email Metadata

**Mailer**: `OrderMailer`
**Method**: `confirmation_email`
**Trigger**: Order creation after successful Stripe Checkout
**Recipient**: Customer email address (from Order.email)

---

## Email Structure

### Headers

| Header      | Value                                                    |
|-------------|----------------------------------------------------------|
| `To`        | Customer email (Order.email)                             |
| `From`      | `no-reply@afida.com` (configured in ApplicationMailer)   |
| `Bcc`       | `orders@afida.com` (for internal tracking)               |
| `Subject`   | `Your Order #[ORDER_NUMBER] is Confirmed!`               |
| `Reply-To`  | `hello@afida.com` (customer service)                     |

**Example subject**: `Your Order #ORD-2025-001234 is Confirmed!`

---

## Email Body

**Format**: HTML with plain text fallback
**Template**: `app/views/order_mailer/confirmation_email.html.erb`

**Content sections**:
1. Greeting with customer name
2. Order confirmation message
3. Order summary (items, totals)
4. Shipping address
5. Link to view order (if user logged in)
6. Customer service contact information

**Plain text fallback**: `app/views/order_mailer/confirmation_email.text.erb`

---

## PDF Attachment

### Attachment Details

| Property           | Value                                |
|--------------------|--------------------------------------|
| **Filename**       | `Order-[ORDER_NUMBER].pdf`           |
| **MIME type**      | `application/pdf`                    |
| **Typical size**   | 100-200 KB                           |
| **Max size**       | 500 KB (target)                      |
| **Generation**     | On-demand (when email sent)          |
| **Encoding**       | Base64 (ActionMailer handles this)   |

**Example filename**: `Order-ORD-2025-001234.pdf`

---

## PDF Content

### Document Structure

**Page size**: A4 (210mm × 297mm)
**Orientation**: Portrait
**Margins**: 20mm all sides

### Content Sections

1. **Header**
   - Company logo (150px width)
   - Company name: "AFIDA"
   - Tagline: "Eco-Friendly Catering Supplies"

2. **Order Information**
   - Title: "ORDER CONFIRMATION"
   - Order number: #ORD-2025-001234
   - Order date: November 25, 2025

3. **Shipping Address**
   - Section title: "SHIPPING ADDRESS"
   - Customer name
   - Full address (line1, line2, city, postal code, country)

4. **Line Items Table**
   - Column headers: Product | Quantity | Price | Total
   - One row per order item
   - Product name (with SKU if applicable)
   - Right-aligned numbers
   - Currency formatted (£)

5. **Totals Section**
   - Subtotal
   - VAT (20%)
   - Shipping
   - Grand total (bold)
   - Right-aligned values

6. **Footer**
   - Thank you message
   - Company contact information
     - Website: www.afida.com
     - Email: hello@afida.com
     - Phone: [company phone]

### Typography & Styling

- **Primary font**: Helvetica (cross-platform compatible)
- **Heading size**: 16pt
- **Body text**: 10pt
- **Table headers**: Bold, 10pt
- **Colors**: Black text, subtle grey for lines/borders
- **Logo**: Full color (company branding)

---

## Implementation

### Mailer Code

**File**: `app/mailers/order_mailer.rb`

**Method implementation**:
```ruby
class OrderMailer < ApplicationMailer
  default bcc: "orders@afida.com"

  def confirmation_email
    @order = params[:order]

    # Generate PDF with error handling
    begin
      pdf_generator = OrderPdfGenerator.new(@order)
      pdf_data = pdf_generator.generate

      # Attach PDF to email
      attachments["Order-#{@order.order_number}.pdf"] = {
        mime_type: 'application/pdf',
        content: pdf_data
      }
    rescue StandardError => e
      # Log error but don't block email delivery
      Rails.logger.error("PDF generation failed for order #{@order.id}: #{e.message}")
      # Email still sends without attachment
    end

    mail(
      to: @order.email,
      subject: "Your Order ##{@order.order_number} is Confirmed!"
    )
  end
end
```

---

## Error Handling

### PDF Generation Failure

**Scenario**: PDF generation raises exception

**Behavior**:
1. Error logged with order ID and exception message
2. Email sends **without** PDF attachment
3. Customer still receives order confirmation
4. Operations team notified (via monitoring)

**Rationale**: Email is critical communication, PDF is enhancement. Email delivery must not be blocked by PDF generation failures.

**Logging example**:
```
[ERROR] PDF generation failed for order 123: Prawn::Errors::InvalidImageData - Logo file not found
```

### Email Delivery Failure

**Scenario**: Email fails to send (Mailgun error, invalid email, etc.)

**Behavior**: Existing Rails email delivery error handling (ActionMailer)
- Error logged
- Retry mechanism (if configured)
- Admin notification

**Not part of this feature**: Email delivery error handling already exists

---

## Testing Strategy

### Unit Tests

**File**: `test/services/order_pdf_generator_test.rb`

Tests for `OrderPdfGenerator`:
- Valid order generates PDF successfully
- PDF contains order number
- PDF contains all line items
- PDF contains correct totals
- PDF contains shipping address
- PDF file size within limits

### Integration Tests

**File**: `test/mailers/order_mailer_test.rb`

Tests for `OrderMailer#confirmation_email`:
```ruby
test "confirmation email has pdf attachment" do
  order = orders(:complete_order)
  email = OrderMailer.with(order: order).confirmation_email

  assert_not_empty email.attachments
  assert_equal 1, email.attachments.count

  attachment = email.attachments.first
  assert_equal "Order-#{order.order_number}.pdf", attachment.filename
  assert_equal 'application/pdf', attachment.content_type
  assert attachment.body.raw_source.length > 0
end

test "confirmation email sends without pdf if generation fails" do
  order = orders(:order_with_missing_data)

  # Stub PDF generator to raise error
  OrderPdfGenerator.any_instance.stubs(:generate).raises(StandardError)

  email = OrderMailer.with(order: order).confirmation_email

  # Email created successfully
  assert_not_nil email

  # No attachments (PDF generation failed)
  assert_empty email.attachments

  # Email still has correct subject and recipient
  assert_equal order.email, email.to.first
  assert_match /Order ##{order.order_number}/, email.subject
end
```

### System Tests

**File**: `test/system/order_confirmation_email_test.rb`

End-to-end test:
```ruby
test "order confirmation email sent with pdf after checkout" do
  # Complete checkout process
  # Assert email delivered
  # Assert email has PDF attachment
  # Assert PDF contains order details
end
```

---

## Performance Targets

| Metric                      | Target  | Rationale                              |
|-----------------------------|---------|----------------------------------------|
| PDF generation time         | < 3s    | Acceptable for email background job    |
| PDF file size               | < 500KB | Email attachment best practice         |
| Email delivery time (total) | < 10s   | Includes PDF generation + Mailgun send |
| Memory usage per generation | < 20MB  | Acceptable for background job          |

---

## Monitoring & Alerts

**Metrics to track**:
- PDF generation success rate (target: > 99%)
- PDF generation time (p50, p95, p99)
- PDF file size distribution
- Email delivery success rate (with and without PDF)

**Alerts**:
- PDF generation failure rate > 1% (30-minute window)
- PDF generation time p95 > 5 seconds
- Email delivery failure rate increases after PDF feature deployment

**Logging**:
- Info: PDF generated successfully (order ID, generation time, file size)
- Error: PDF generation failed (order ID, exception, stack trace)
- Warning: PDF file size exceeds 500KB (order ID, actual size)

---

## Future Enhancements (Not in Phase 1)

1. **Internationalization**: Support multiple languages in PDF
2. **Custom branding**: Different PDF templates for B2B vs B2C customers
3. **Digital signature**: Add digital signature to PDF for authenticity
4. **QR code**: Add QR code for easy order lookup
5. **Packing slip**: Generate separate packing slip PDF for warehouse
6. **Async generation**: Move PDF generation to background job (Solid Queue)
7. **Caching**: Cache PDFs with Active Storage for resending

---

## Example Email Flow

### Successful Order with PDF

```
1. Customer completes Stripe Checkout
   ↓
2. CheckoutsController#success creates Order
   ↓
3. OrderMailer.confirmation_email(order: @order).deliver_later
   ↓
4. Background job processes email
   ↓
5. OrderPdfGenerator.new(@order).generate
   ↓ (generates PDF in ~2 seconds)
6. PDF attached to email
   ↓
7. Email sent via Mailgun
   ↓
8. Customer receives email with PDF attachment
```

### Order with PDF Generation Failure

```
1. Customer completes Stripe Checkout
   ↓
2. CheckoutsController#success creates Order
   ↓
3. OrderMailer.confirmation_email(order: @order).deliver_later
   ↓
4. Background job processes email
   ↓
5. OrderPdfGenerator.new(@order).generate
   ↓ (raises StandardError - logo missing)
6. Exception rescued, error logged
   ↓
7. Email sent WITHOUT PDF attachment
   ↓
8. Customer receives email (no attachment)
   ↓
9. Operations team alerted (monitoring)
   ↓
10. Issue investigated and fixed
```

---

## Summary

**Email**: Order confirmation with PDF attachment
**Trigger**: Order creation after checkout
**Attachment**: Professional PDF receipt/invoice
**Error handling**: Graceful degradation (email sends without PDF if generation fails)
**Performance**: < 3 seconds PDF generation, < 500KB file size
**Testing**: Unit, integration, and system tests ensure reliability
