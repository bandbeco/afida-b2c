# GA4 E-commerce Tracking Setup Plan

**Purpose:** Track revenue attribution for the marketing partnership
**Priority:** Must complete before any paid campaigns launch

---

## Overview

You need to track:
1. Where visitors come from (traffic source)
2. What they do on site (behaviour)
3. What they buy (conversions + revenue)
4. Which marketing channel gets credit (attribution)

---

## Step 1: Create GA4 Property

### If Starting Fresh

1. Go to [analytics.google.com](https://analytics.google.com)
2. Click Admin (gear icon) → Create Property
3. Property name: "Afida E-commerce"
4. Time zone: United Kingdom
5. Currency: British Pound (£)
6. Business type: E-commerce
7. Business size: Small

### Get Your Measurement ID

After creation:
1. Go to Admin → Data Streams → Web
2. Add stream with your domain: `afida.com`
3. Copy the Measurement ID (format: `G-XXXXXXXXXX`)

---

## Step 2: Install Google Tag Manager

GTM gives you flexibility to add/modify tracking without code changes.

### Create GTM Account

1. Go to [tagmanager.google.com](https://tagmanager.google.com)
2. Create account: "Afida"
3. Create container: "afida.com" (Web)
4. Copy the two code snippets

### Add GTM to Rails

Create a partial for the GTM snippets:

```erb
<!-- app/views/layouts/_google_tag_manager.html.erb -->

<!-- Google Tag Manager - HEAD (goes in <head>) -->
<script>(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
'https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
})(window,document,'script','dataLayer','GTM-XXXXXXX');</script>

<!-- Google Tag Manager - BODY (goes after opening <body>) -->
<noscript><iframe src="https://www.googletagmanager.com/ns.html?id=GTM-XXXXXXX"
height="0" width="0" style="display:none;visibility:hidden"></iframe></noscript>
```

Add to `app/views/layouts/application.html.erb`:
- Head snippet in `<head>` section
- Body snippet right after `<body>` tag

### Configure GA4 in GTM

1. In GTM, go to Tags → New
2. Tag type: Google Analytics: GA4 Configuration
3. Measurement ID: Your `G-XXXXXXXXXX`
4. Trigger: All Pages
5. Save and name it "GA4 - Configuration"

---

## Step 3: Set Up Data Layer

The data layer passes e-commerce data to GTM/GA4.

### Add Data Layer Initialisation

In your application layout, before GTM scripts:

```erb
<script>
  window.dataLayer = window.dataLayer || [];
</script>
```

### Push E-commerce Events

Create a helper for e-commerce tracking:

```ruby
# app/helpers/analytics_helper.rb

module AnalyticsHelper
  def ecommerce_item_data(item)
    variant = item.respond_to?(:product_variant) ? item.product_variant : item
    product = variant.product

    {
      item_id: variant.sku,
      item_name: product.name,
      item_category: product.category&.name,
      item_variant: variant.name,
      price: variant.price.to_f,
      quantity: item.respond_to?(:quantity) ? item.quantity : 1
    }
  end

  def ecommerce_items_data(items)
    items.map { |item| ecommerce_item_data(item) }
  end
end
```

---

## Step 4: Track Key E-commerce Events

### View Item (Product Page)

In `app/views/products/show.html.erb`:

```erb
<script>
  dataLayer.push({ ecommerce: null }); // Clear previous
  dataLayer.push({
    event: "view_item",
    ecommerce: {
      currency: "GBP",
      value: <%= @product.default_variant.price.to_f %>,
      items: [{
        item_id: "<%= @product.default_variant.sku %>",
        item_name: "<%= j @product.name %>",
        item_category: "<%= j @product.category&.name %>",
        price: <%= @product.default_variant.price.to_f %>
      }]
    }
  });
</script>
```

### Add to Cart

In your cart item creation response (Turbo Stream or JS):

```javascript
dataLayer.push({ ecommerce: null });
dataLayer.push({
  event: "add_to_cart",
  ecommerce: {
    currency: "GBP",
    value: price * quantity,
    items: [{
      item_id: sku,
      item_name: productName,
      item_category: category,
      price: price,
      quantity: quantity
    }]
  }
});
```

### Begin Checkout

In `app/views/checkouts/new.html.erb` (or wherever checkout starts):

```erb
<script>
  dataLayer.push({ ecommerce: null });
  dataLayer.push({
    event: "begin_checkout",
    ecommerce: {
      currency: "GBP",
      value: <%= Current.cart.total_amount.to_f %>,
      items: <%= raw ecommerce_items_data(Current.cart.cart_items).to_json %>
    }
  });
</script>
```

### Purchase (Most Important!)

On the order confirmation/success page:

```erb
<script>
  dataLayer.push({ ecommerce: null });
  dataLayer.push({
    event: "purchase",
    ecommerce: {
      transaction_id: "<%= @order.id %>",
      value: <%= @order.total_amount.to_f %>,
      tax: <%= @order.vat_amount.to_f %>,
      shipping: <%= @order.shipping_amount.to_f %>,
      currency: "GBP",
      items: <%= raw ecommerce_items_data(@order.order_items).to_json %>
    }
  });
</script>
```

---

## Step 5: Configure GTM Tags for Events

For each e-commerce event, create a tag in GTM:

### Example: Purchase Event Tag

1. Tags → New → GA4 Event
2. Configuration Tag: Select your GA4 Configuration tag
3. Event Name: `purchase`
4. Event Parameters:
   - `transaction_id`: `{{DLV - transaction_id}}`
   - `value`: `{{DLV - value}}`
   - `currency`: `GBP`
5. Trigger: Custom Event, Event name = `purchase`

### Create Data Layer Variables

For each value you need, create a Data Layer Variable:
1. Variables → User-Defined Variables → New
2. Variable Type: Data Layer Variable
3. Name: `ecommerce.transaction_id` (for transaction_id)
4. Repeat for: `ecommerce.value`, `ecommerce.items`, etc.

---

## Step 6: Enable E-commerce Reports in GA4

1. GA4 Admin → Data Display → Data Streams
2. Click your web stream
3. Enhanced Measurement: Ensure it's ON
4. Go to Admin → Property Settings → Data Collection
5. Enable Google Signals (for cross-device tracking)

---

## Step 7: Link Google Ads (When Ready)

1. GA4 Admin → Product Links → Google Ads Links
2. Link your Google Ads account
3. Enable:
   - Personalised advertising
   - Auto-tagging

This allows:
- Import GA4 conversions into Google Ads
- See Google Ads data in GA4
- Use GA4 audiences for remarketing

---

## Step 8: Set Up Conversions

1. GA4 → Admin → Data Display → Events
2. Find `purchase` event
3. Toggle "Mark as conversion" ON
4. Also mark: `begin_checkout`, `add_to_cart` (as micro-conversions)

---

## Step 9: Test Everything

### GTM Preview Mode

1. In GTM, click Preview
2. Enter your site URL
3. Browse your site and make a test purchase
4. Verify each event fires in the preview panel

### GA4 DebugView

1. GA4 → Admin → Data Display → DebugView
2. With GTM Preview active, you'll see events in real-time
3. Verify `purchase` event includes all parameters

### Real-Time Reports

1. GA4 → Reports → Real-time
2. Make another test purchase
3. Should see conversion within seconds

---

## Step 10: Set Up Attribution Reporting

### Default Attribution Model

GA4 uses data-driven attribution by default, which is good. But verify:

1. GA4 Admin → Data Display → Attribution Settings
2. Reporting attribution model: Data-driven (recommended)
3. Lookback window: 90 days (matches your proposal)

### Custom Report for Revenue Share

Create a report showing revenue by channel:

1. GA4 → Explore → Blank
2. Dimensions: Session source/medium, First user source/medium
3. Metrics: Purchase revenue, Transactions
4. Filter: Exclude your test orders

---

## Validation Checklist

Before launching paid campaigns, verify:

- [ ] GTM loads on all pages
- [ ] GA4 receives pageview data
- [ ] `view_item` fires on product pages
- [ ] `add_to_cart` fires when items added
- [ ] `begin_checkout` fires at checkout start
- [ ] `purchase` fires on confirmation page
- [ ] Purchase event includes correct revenue
- [ ] Google Ads account linked
- [ ] Purchase marked as conversion
- [ ] Test order appears in GA4 reports

---

## Excluding B2B Customers

For the revenue share agreement, you need to exclude existing B2B customers.

### Option 1: Custom Dimension

1. Create custom dimension in GA4: `customer_type`
2. On purchase, check if email matches B2B list
3. Pass `customer_type: "b2b"` or `customer_type: "new"`
4. Filter reports to exclude `b2b`

### Option 2: Separate Reporting

1. Export monthly purchase data
2. Match against B2B email list in spreadsheet
3. Calculate net revenue for share

Option 2 is simpler to start; move to Option 1 if volume justifies it.

---

## Monthly Reporting Template

For your revenue share reports:

```
AFIDA E-COMMERCE PERFORMANCE - [MONTH YEAR]

ATTRIBUTED REVENUE
==================
Organic Search:     £X,XXX
Paid Search:        £X,XXX
Paid Social:        £X,XXX
Email:              £X,XXX
------------------------
Total Attributed:   £X,XXX

EXCLUSIONS
==================
B2B Customers:      £X,XXX
Direct/Other:       £X,XXX

NET ATTRIBUTED:     £X,XXX

REVENUE SHARE (15%): £X,XXX

Due by: [DATE]
```
