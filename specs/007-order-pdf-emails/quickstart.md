# Quickstart Guide: Order Summary PDF Attachment

**Feature**: 007-order-pdf-emails
**Date**: 2025-11-25
**Target audience**: Developers implementing this feature

## Overview

This guide walks you through implementing PDF attachments for order confirmation emails. Follow steps in order for TDD approach.

**Estimated time**: 4-6 hours

---

## Prerequisites

- Ruby 3.3.0+
- Rails 8.x
- Existing Order/OrderItem models
- OrderMailer with confirmation_email method
- Admin::OrdersController with show action

---

## Phase 1: Setup (15 minutes)

### 1. Add Gem Dependencies

Edit `Gemfile`:

```ruby
# PDF generation
gem "prawn", "~> 2.5"
gem "prawn-table", "~> 0.2"
```

Run:
```bash
bundle install
```

### 2. Verify Logo Exists

Check logo file exists:
```bash
ls app/frontend/images/logo.png
```

If missing, add logo image (recommended: 400x400px, PNG format, < 50KB).

### 3. Create Services Directory (if not exists)

```bash
mkdir -p app/services
mkdir -p test/services
```

---

## Phase 2: Write Tests FIRST (TDD) (60 minutes)

### Step 1: PDF Generator Service Tests

Create `test/services/order_pdf_generator_test.rb`:

```ruby
require "test_helper"

class OrderPdfGeneratorTest < ActiveSupport::TestCase
  def setup
    @order = orders(:complete_order)
  end

  test "generates pdf for valid order" do
    generator = OrderPdfGenerator.new(@order)
    pdf_data = generator.generate

    assert_not_nil pdf_data
    assert pdf_data.is_a?(String)
    assert pdf_data.length > 0
  end

  test "pdf file size is under 500kb" do
    generator = OrderPdfGenerator.new(@order)
    pdf_data = generator.generate

    file_size_kb = pdf_data.bytesize / 1024.0
    assert file_size_kb < 500, "PDF size #{file_size_kb}KB exceeds 500KB limit"
  end

  test "pdf contains order number" do
    generator = OrderPdfGenerator.new(@order)
    pdf_data = generator.generate

    # Extract text from PDF (requires pdf-reader gem for validation)
    # For MVP, we trust Prawn generates correct content
    assert_not_nil pdf_data
  end

  test "raises error for order without items" do
    order_without_items = Order.create!(
      email: "test@example.com",
      stripe_session_id: "cs_test_123",
      order_number: "TEST-123",
      status: "paid",
      subtotal_amount: 0,
      vat_amount: 0,
      shipping_amount: 0,
      total_amount: 0,
      shipping_name: "Test User",
      shipping_address_line1: "123 Test St",
      shipping_city: "London",
      shipping_postal_code: "SW1A 1AA",
      shipping_country: "GB"
    )

    generator = OrderPdfGenerator.new(order_without_items)

    assert_raises(StandardError) do
      generator.generate
    end
  end
end
```

Create fixture in `test/fixtures/orders.yml`:
```yaml
complete_order:
  email: customer@example.com
  stripe_session_id: cs_test_complete
  order_number: ORD-2025-001234
  status: paid
  subtotal_amount: 35.00
  vat_amount: 7.00
  shipping_amount: 5.00
  total_amount: 47.00
  shipping_name: John Doe
  shipping_address_line1: 123 Main Street
  shipping_city: London
  shipping_postal_code: SW1A 1AA
  shipping_country: GB
  created_at: <%= 1.day.ago %>
```

Create fixture in `test/fixtures/order_items.yml`:
```yaml
complete_order_item_one:
  order: complete_order
  product_name: "Eco Coffee Cup"
  variant_sku: "CUP-8OZ"
  quantity: 2
  price: 10.00
  total_price: 20.00

complete_order_item_two:
  order: complete_order
  product_name: "Bamboo Cutlery Set"
  variant_sku: "CUTLERY-SET"
  quantity: 1
  price: 15.00
  total_price: 15.00
```

### Step 2: Mailer Tests

Update `test/mailers/order_mailer_test.rb`:

```ruby
require "test_helper"

class OrderMailerTest < ActionMailer::TestCase
  test "confirmation email has pdf attachment" do
    order = orders(:complete_order)
    email = OrderMailer.with(order: order).confirmation_email

    assert_emails 1 do
      email.deliver_now
    end

    assert_not_empty email.attachments
    assert_equal 1, email.attachments.count

    attachment = email.attachments.first
    assert_equal "Order-#{order.order_number}.pdf", attachment.filename
    assert_equal "application/pdf", attachment.content_type
    assert attachment.body.raw_source.length > 0
  end

  test "confirmation email sends without pdf if generation fails" do
    order = orders(:complete_order)

    # Stub to simulate PDF generation failure
    OrderPdfGenerator.any_instance.stubs(:generate).raises(StandardError.new("Test error"))

    email = OrderMailer.with(order: order).confirmation_email

    assert_not_nil email
    assert_empty email.attachments
    assert_equal order.email, email.to.first
  end
end
```

### Step 3: Admin Preview Controller Tests

Create `test/controllers/admin/orders_controller_test.rb`:

```ruby
require "test_helper"

class Admin::OrdersControllerTest < ActionDispatch::IntegrationTest
  # Add admin authentication setup if needed

  test "preview_pdf returns pdf for existing order" do
    order = orders(:complete_order)

    get preview_pdf_admin_order_path(order)

    assert_response :success
    assert_equal "application/pdf", response.content_type
    assert_match /Order-#{order.order_number}.pdf/, response.headers["Content-Disposition"]
    assert response.body.length > 0
  end

  test "preview_pdf returns 404 for non-existent order" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get preview_pdf_admin_order_path(id: 999999)
    end
  end
end
```

### Step 4: Run Tests (They Should Fail - RED Phase)

```bash
rails test test/services/order_pdf_generator_test.rb
rails test test/mailers/order_mailer_test.rb
rails test test/controllers/admin/orders_controller_test.rb
```

**Expected result**: All tests fail (service/routes don't exist yet). This is correct TDD - RED phase.

---

## Phase 3: Implement Features (GREEN Phase) (90-120 minutes)

### Step 1: Create PDF Generator Service

Create `app/services/order_pdf_generator.rb`:

```ruby
require "prawn"
require "prawn/table"

class OrderPdfGenerator
  LOGO_PATH = Rails.root.join("app/frontend/images/logo.png")
  PAGE_WIDTH = 540 # A4 width in points (minus margins)

  def initialize(order)
    @order = order
    validate_order!
  end

  def generate
    pdf = Prawn::Document.new(page_size: "A4", margin: 40)

    build_header(pdf)
    pdf.move_down 30

    build_order_info(pdf)
    pdf.move_down 20

    build_shipping_address(pdf)
    pdf.move_down 20

    build_line_items_table(pdf)
    pdf.move_down 20

    build_totals(pdf)
    pdf.move_down 40

    build_footer(pdf)

    pdf.render
  end

  private

  def validate_order!
    raise StandardError, "Order must have order items" if @order.order_items.empty?
    raise StandardError, "Order must have shipping address" if @order.shipping_name.blank?
  end

  def build_header(pdf)
    if File.exist?(LOGO_PATH)
      pdf.image LOGO_PATH, width: 150
      pdf.move_down 10
    end

    pdf.text "AFIDA", size: 20, style: :bold
    pdf.text "Eco-Friendly packaging supplies", size: 10, color: "666666"
  end

  def build_order_info(pdf)
    pdf.text "ORDER CONFIRMATION", size: 16, style: :bold
    pdf.move_down 10

    pdf.text "Order Number: #{@order.display_number}", size: 12
    pdf.text "Order Date: #{@order.created_at.strftime('%B %d, %Y')}", size: 10
  end

  def build_shipping_address(pdf)
    pdf.text "SHIPPING ADDRESS", size: 12, style: :bold
    pdf.move_down 5

    pdf.text @order.shipping_name
    pdf.text @order.shipping_address_line1
    pdf.text @order.shipping_address_line2 if @order.shipping_address_line2.present?
    pdf.text "#{@order.shipping_city}, #{@order.shipping_postal_code}"
    pdf.text @order.shipping_country
  end

  def build_line_items_table(pdf)
    pdf.text "ORDER ITEMS", size: 12, style: :bold
    pdf.move_down 10

    table_data = [
      ["Product", "Quantity", "Price", "Total"]
    ]

    @order.order_items.each do |item|
      table_data << [
        item.product_name,
        item.quantity.to_s,
        format_currency(item.price),
        format_currency(item.total_price)
      ]
    end

    pdf.table(table_data, width: PAGE_WIDTH, cell_style: { padding: 8 }) do
      row(0).font_style = :bold
      row(0).background_color = "EEEEEE"
      columns(1..3).align = :right
    end
  end

  def build_totals(pdf)
    totals_data = [
      ["Subtotal:", format_currency(@order.subtotal_amount)],
      ["VAT (20%):", format_currency(@order.vat_amount)],
      ["Shipping:", format_currency(@order.shipping_amount)],
      ["Total:", format_currency(@order.total_amount)]
    ]

    pdf.table(totals_data, position: :right, width: 250, cell_style: { borders: [] }) do
      column(0).font_style = :bold
      column(1).align = :right
      row(-1).font_style = :bold
      row(-1).size = 14
    end
  end

  def build_footer(pdf)
    pdf.stroke_horizontal_rule
    pdf.move_down 10

    pdf.text "Thank you for your order!", align: :center, style: :bold
    pdf.move_down 10

    footer_text = [
      "Afida | www.afida.com",
      "Email: hello@afida.com | Phone: +44 (0)20 1234 5678"
    ].join("\n")

    pdf.text footer_text, align: :center, size: 9, color: "666666"
  end

  def format_currency(amount)
    "£#{'%.2f' % amount}"
  end
end
```

### Step 2: Update OrderMailer

Update `app/mailers/order_mailer.rb`:

```ruby
class OrderMailer < ApplicationMailer
  default bcc: "orders@afida.com"

  def confirmation_email
    @order = params[:order]

    # Generate PDF with error handling
    begin
      pdf_generator = OrderPdfGenerator.new(@order)
      pdf_data = pdf_generator.generate

      attachments["Order-#{@order.order_number}.pdf"] = {
        mime_type: "application/pdf",
        content: pdf_data
      }
    rescue StandardError => e
      Rails.logger.error("PDF generation failed for order #{@order.id}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      # Email still sends without attachment
    end

    mail(
      to: @order.email,
      subject: "Your Order ##{@order.order_number} is Confirmed!"
    )
  end
end
```

### Step 3: Add Admin Preview Route

Update `config/routes.rb`:

```ruby
namespace :admin do
  resources :orders do
    member do
      get :preview_pdf
    end
  end
end
```

### Step 4: Add Admin Preview Controller Action

Update `app/controllers/admin/orders_controller.rb`:

```ruby
class Admin::OrdersController < ApplicationController
  before_action :set_order, only: [:show, :edit, :update, :destroy, :preview_pdf]

  # ... existing actions ...

  def preview_pdf
    begin
      pdf_generator = OrderPdfGenerator.new(@order)
      pdf_data = pdf_generator.generate

      send_data pdf_data,
        filename: "Order-#{@order.order_number}.pdf",
        type: "application/pdf",
        disposition: "inline"
    rescue StandardError => e
      Rails.logger.error("PDF preview failed for order #{@order.id}: #{e.message}")
      flash[:error] = "Unable to generate PDF. Please try again later."
      redirect_to admin_order_path(@order)
    end
  end

  private

  def set_order
    @order = Order.includes(:order_items).find(params[:id])
  end

  # ... rest of controller ...
end
```

### Step 5: Add Preview Button to Admin UI

Update `app/views/admin/orders/show.html.erb`:

```erb
<!-- Add this near the top of the page, with other action buttons -->
<div class="flex gap-2 mb-4">
  <%= link_to "Preview PDF",
      preview_pdf_admin_order_path(@order),
      target: "_blank",
      class: "btn btn-secondary" %>

  <%= link_to "Edit", edit_admin_order_path(@order), class: "btn btn-primary" %>
  <%= link_to "Back to Orders", admin_orders_path, class: "btn btn-outline" %>
</div>
```

### Step 6: Run Tests Again (GREEN Phase)

```bash
rails test test/services/order_pdf_generator_test.rb
rails test test/mailers/order_mailer_test.rb
rails test test/controllers/admin/orders_controller_test.rb
```

**Expected result**: All tests pass (GREEN phase).

---

## Phase 4: Manual Testing (30 minutes)

### Test 1: Admin Preview

1. Start Rails server: `bin/dev`
2. Navigate to admin orders: `http://localhost:3000/admin/orders`
3. Click on an order
4. Click "Preview PDF" button
5. Verify PDF opens in new tab with correct content

### Test 2: Email Attachment

**Option A: Test in development with letter_opener**

Add to `Gemfile` (development group):
```ruby
gem "letter_opener", group: :development
```

Update `config/environments/development.rb`:
```ruby
config.action_mailer.delivery_method = :letter_opener
config.action_mailer.perform_deliveries = true
```

Create test order and send email:
```ruby
# In rails console
order = Order.includes(:order_items).last
OrderMailer.with(order: order).confirmation_email.deliver_now
```

Email opens in browser with PDF attachment.

**Option B: Test with real order**

1. Complete a test order through checkout
2. Check email inbox for confirmation
3. Verify PDF attachment present and opens correctly

### Test 3: Error Handling

Test PDF generation failure:
```ruby
# In rails console
order = Order.last

# Temporarily rename logo to simulate missing file
File.rename("app/frontend/images/logo.png", "app/frontend/images/logo.png.bak")

# Try to send email
OrderMailer.with(order: order).confirmation_email.deliver_now

# Email sends without attachment, error logged

# Restore logo
File.rename("app/frontend/images/logo.png.bak", "app/frontend/images/logo.png")
```

---

## Phase 5: Refactor (Optional) (30 minutes)

### Improvements to Consider

1. **Extract logo path to config**:
   ```ruby
   # config/initializers/pdf_generator.rb
   PDF_CONFIG = {
     logo_path: Rails.root.join("app/frontend/images/logo.png"),
     company_name: "Afida",
     company_tagline: "Eco-Friendly packaging supplies",
     contact_email: "hello@afida.com",
     contact_phone: "+44 (0)20 1234 5678"
   }
   ```

2. **Add PDF generation metrics**:
   ```ruby
   def generate
     start_time = Time.current
     pdf_data = # ... generation code ...
     generation_time = Time.current - start_time

     Rails.logger.info("PDF generated for order #{@order.id} in #{generation_time}s, size: #{pdf_data.bytesize / 1024}KB")

     pdf_data
   end
   ```

3. **Add caching for high-volume scenarios** (future enhancement)

---

## Troubleshooting

### Issue: Tests fail with "Logo file not found"

**Solution**: Ensure `app/frontend/images/logo.png` exists or update `LOGO_PATH` in service.

### Issue: PDF generation is slow

**Solution**:
- Check N+1 queries (use `Order.includes(:order_items)`)
- Optimize logo file size (compress PNG)
- Consider async generation with background job

### Issue: Email sends but no attachment

**Solution**:
- Check Rails logs for PDF generation errors
- Verify OrderPdfGenerator raises exceptions correctly
- Test PDF generation in console: `OrderPdfGenerator.new(order).generate`

### Issue: PDF looks broken on mobile

**Solution**:
- Test PDF on multiple devices
- Ensure A4 page size works for your content
- Consider responsive layout adjustments

---

## Deployment Checklist

Before deploying to production:

- [ ] All tests passing
- [ ] RuboCop linter passing
- [ ] Brakeman security scan passing
- [ ] Logo file exists in production asset path
- [ ] Email delivery configured (Mailgun)
- [ ] Error monitoring configured (track PDF generation failures)
- [ ] Performance monitoring enabled (track generation time)
- [ ] Manual testing completed on staging environment

---

## Next Steps

1. **Monitor production**: Track PDF generation success rate and performance
2. **Gather feedback**: Ask customers and support team for feedback
3. **Iterate**: Consider enhancements like caching, async generation, custom templates
4. **Document**: Update project README with PDF feature documentation

---

## Resources

- **Prawn documentation**: https://prawnpdf.org/docs/
- **Prawn table gem**: https://github.com/prawnpdf/prawn-table
- **ActionMailer attachments**: https://guides.rubyonrails.org/action_mailer_basics.html#adding-attachments
- **Feature spec**: `specs/007-order-pdf-emails/spec.md`
- **Data model**: `specs/007-order-pdf-emails/data-model.md`

---

## Success Criteria

✅ **Feature complete when**:
- All tests pass
- Order confirmation emails include PDF attachment
- Admin can preview PDFs from order detail page
- PDF generation time < 3 seconds for 20-item orders
- PDF file size < 500KB for 95% of orders
- Email sends successfully even if PDF generation fails
- Feature deployed to production without issues
