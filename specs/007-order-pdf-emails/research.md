# Research: Order Summary PDF Attachment

**Feature**: 007-order-pdf-emails
**Date**: 2025-11-25
**Status**: Complete

## Research Questions

### 1. PDF Generation Library Selection

**Question**: Which PDF generation library should we use for Rails 8?

**Research conducted**: Analyzed top Ruby PDF libraries for Rails applications

**Options evaluated**:

1. **Prawn** (Pure Ruby)
   - Pros: Pure Ruby implementation, no external dependencies, excellent documentation, highly customizable, battle-tested
   - Cons: Manual layout management (more code), steeper learning curve
   - Performance: Fast, efficient for programmatic PDFs
   - File size: Small (good compression)
   - Platform compatibility: Excellent (cross-platform)

2. **Wicked PDF** (wkhtmltopdf wrapper)
   - Pros: Uses HTML/CSS for layout (leverage existing styling), familiar to web developers
   - Cons: Requires external binary (wkhtmltopdf), harder to deploy, binary maintenance overhead
   - Performance: Slower (spawns process for each PDF)
   - File size: Larger (HTML rendering overhead)
   - Platform compatibility: Requires platform-specific binary

3. **Grover** (Puppeteer/Chrome headless)
   - Pros: Modern HTML/CSS support, accurate rendering
   - Cons: Requires Node.js and Chrome/Chromium, heavyweight, deployment complexity
   - Performance: Slowest (browser overhead)
   - File size: Larger
   - Platform compatibility: Requires Chrome installation

**Decision**: **Prawn**

**Rationale**:
- **No external dependencies**: Pure Ruby gem, no binary installation required
- **Performance**: Meets <3 second requirement easily, synchronous generation acceptable
- **File size**: Excellent compression, easily meets <500KB target
- **Platform compatibility**: Works on all platforms without platform-specific binaries
- **Deployment simplicity**: Just a gem, no additional system dependencies
- **Control**: Full control over PDF structure, perfect for structured receipts/invoices
- **Rails ecosystem**: Well-integrated with Rails, ActiveStorage compatible

**Alternatives considered**:
- **Wicked PDF rejected**: External binary dependency adds deployment complexity, slower performance, larger file sizes
- **Grover rejected**: Too heavyweight (Chrome + Node.js), overkill for simple receipts

**Implementation approach**:
- Use `prawn` gem for PDF generation
- Use `prawn-table` for line item tables
- Embed logo as image using Prawn's image support
- Store logo in `app/frontend/images/` (already available)

---

### 2. PDF Storage Strategy

**Question**: Should we cache/store generated PDFs or generate on-demand?

**Research conducted**: Evaluated storage patterns for transactional documents

**Options evaluated**:

1. **On-demand generation only**
   - Pros: No storage overhead, always up-to-date if order changes, simpler code
   - Cons: Regenerates on every preview/resend
   - Performance impact: Minimal (<3s generation time acceptable)

2. **Cache with Active Storage**
   - Pros: Faster subsequent access, reduces server load
   - Cons: Storage costs, cache invalidation complexity, stale data risk
   - Performance impact: First generation + storage write overhead

3. **Permanent storage**
   - Pros: Historical record, faster access, audit trail
   - Cons: Highest storage costs, requires cleanup strategy
   - Performance impact: Storage write on every order

**Decision**: **On-demand generation only (Phase 1)**

**Rationale**:
- **Simplicity**: Meets MVP requirements without storage complexity
- **Performance acceptable**: <3 second generation meets user needs
- **No staleness**: Always reflects current order state
- **Cost**: Zero storage costs
- **Future-proof**: Can add caching later if needed (clear upgrade path)

**Implementation approach**:
- Generate PDF on-the-fly when needed (email attachment, admin preview)
- Use `attachment.body = pdf_data` in mailer (ActionMailer handles attachment)
- Admin preview returns PDF directly as response

**Future enhancement** (post-MVP):
- If preview usage is high, consider caching with Active Storage
- Add background job for async generation if synchronous too slow
- Metrics: Monitor PDF generation time in production

---

### 3. Email Attachment Best Practices

**Question**: How should we attach PDFs to Rails ActionMailer emails?

**Research conducted**: Rails ActionMailer attachment patterns

**Best practices found**:
1. Use `attachments['filename.pdf'] = pdf_data` syntax
2. Set MIME type explicitly for cross-client compatibility
3. Handle generation errors gracefully (send email without attachment if PDF fails)
4. Keep attachment size reasonable (<500KB recommended, <2MB max)
5. Use inline disposition for preview, attachment for download

**Decision**: Standard ActionMailer attachment with error handling

**Implementation approach**:
```ruby
# In OrderMailer
def confirmation_email
  @order = params[:order]

  # Generate PDF with error handling
  begin
    pdf_generator = OrderPdfGenerator.new(@order)
    pdf_data = pdf_generator.generate

    attachments["Order-#{@order.order_number}.pdf"] = {
      mime_type: 'application/pdf',
      content: pdf_data
    }
  rescue => e
    # Log error but don't block email
    Rails.logger.error("PDF generation failed for order #{@order.id}: #{e.message}")
    # Email still sends without attachment
  end

  mail(to: @order.email, subject: "...")
end
```

**Error handling strategy**:
- Log PDF generation errors with order ID
- Send email without attachment if PDF fails (email is critical, PDF is nice-to-have)
- Monitor error rates with application monitoring
- Alert if error rate exceeds threshold

---

### 4. Admin Preview Implementation

**Question**: How should admin users preview PDFs?

**Research conducted**: Rails PDF response patterns

**Options evaluated**:

1. **Inline rendering** (display in browser)
   - Pros: Immediate preview, no download required
   - Cons: Browser compatibility varies
   - Implementation: `send_data pdf, disposition: 'inline'`

2. **Download**
   - Pros: Universal compatibility
   - Cons: Extra step for user
   - Implementation: `send_data pdf, disposition: 'attachment'`

3. **Modal with inline preview**
   - Pros: Best UX (stay on page)
   - Cons: More complex (needs PDF.js or similar)
   - Implementation: JavaScript PDF viewer

**Decision**: **Inline rendering with fallback**

**Implementation approach**:
```ruby
# In Admin::OrdersController
def preview_pdf
  @order = Order.find(params[:id])
  pdf_generator = OrderPdfGenerator.new(@order)
  pdf_data = pdf_generator.generate

  send_data pdf_data,
    filename: "Order-#{@order.order_number}.pdf",
    type: 'application/pdf',
    disposition: 'inline'  # Try to display in browser
end
```

**UI approach**:
- Add "Preview PDF" button on admin order show page
- Link to preview_pdf action (opens in new tab)
- Browser will display inline if supported, download otherwise

---

### 5. Branding and Layout

**Question**: What should the PDF layout and branding look like?

**Research conducted**: E-commerce receipt/invoice best practices

**Standard receipt structure**:
1. **Header**: Logo + Company name
2. **Order info**: Order number, date
3. **Addresses**: Shipping address (billing if different)
4. **Line items table**: Product, Quantity, Price, Total
5. **Totals**: Subtotal, VAT, Shipping, Total
6. **Footer**: Company contact info, terms

**Decision**: Professional invoice-style layout

**Implementation details**:
- **Logo**: 150px width, top-left, using `app/frontend/images/logo.png`
- **Colors**: Afida brand colors (will use existing brand palette)
- **Typography**: Standard fonts (Helvetica/sans-serif) for compatibility
- **Table**: Prawn-table gem for clean line item display
- **Spacing**: Professional margins and padding
- **Page size**: A4 (standard)

**Layout mockup** (text representation):
```
┌────────────────────────────────────────┐
│ [LOGO]  AFIDA                          │
│         Eco-Friendly packaging supplies │
│                                        │
│ ORDER CONFIRMATION                     │
│ Order #: ORD-2025-001234               │
│ Date: November 25, 2025                │
│                                        │
│ SHIPPING ADDRESS                       │
│ John Doe                               │
│ 123 Main St, London, SW1A 1AA, GB     │
│                                        │
│ ORDER ITEMS                            │
│ ┌─────────┬────┬────────┬──────────┐  │
│ │ Product │ Qty│  Price │    Total │  │
│ ├─────────┼────┼────────┼──────────┤  │
│ │ Item 1  │  2 │ £10.00 │  £20.00  │  │
│ │ Item 2  │  1 │ £15.00 │  £15.00  │  │
│ └─────────┴────┴────────┴──────────┘  │
│                                        │
│                      Subtotal: £35.00  │
│                     VAT (20%): £7.00   │
│                      Shipping: £5.00   │
│                    ───────────────────  │
│                         Total: £47.00  │
│                                        │
│ Thank you for your order!              │
│                                        │
│ ────────────────────────────────────── │
│ Afida | www.afida.com                 │
│ Email: hello@afida.com | Tel: +44...  │
└────────────────────────────────────────┘
```

---

## Technology Stack Summary

**Final decisions**:

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| PDF Library | Prawn + prawn-table | Pure Ruby, no dependencies, excellent performance |
| Storage | On-demand generation | Simplicity, no storage costs, meets performance goals |
| Email attachment | ActionMailer with error handling | Standard Rails pattern, graceful degradation |
| Admin preview | Inline rendering (send_data) | Simple, browser-native, no JavaScript needed |
| Layout | Invoice-style with branding | Professional, industry-standard receipt format |

**Gem dependencies to add**:
```ruby
# Gemfile
gem "prawn", "~> 2.5"
gem "prawn-table", "~> 0.2"
```

**No schema changes required**: Feature uses existing Order/OrderItem models

**Performance estimate**:
- PDF generation: ~1-2 seconds for typical order (well under 3s target)
- File size: ~100-200KB typical (well under 500KB target)
- Memory: ~10-20MB per generation (acceptable)

**Risk assessment**:
- **Low risk**: Established technology (Prawn mature and stable)
- **No deployment complexity**: Pure Ruby gem, no binaries
- **Graceful degradation**: Email sends even if PDF fails
- **Easy testing**: Pure Ruby, testable without browser

## Next Phase

Phase 0 research complete. All "NEEDS CLARIFICATION" items resolved.

**Ready for Phase 1**: Data model and contracts design.
