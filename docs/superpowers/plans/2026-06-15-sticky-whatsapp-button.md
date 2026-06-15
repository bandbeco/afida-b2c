# Sticky WhatsApp Button Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a site-wide floating WhatsApp button (round, 64px, WhatsApp-green, bottom-right) to the storefront that opens a WhatsApp chat to +44 7595 119603 with a prefilled message, lifting above the mobile add-to-cart bar on product pages.

**Architecture:** A single shared partial `app/views/shared/_whatsapp_button.html.erb` rendered once in the storefront layout (`application.html.erb`). It is a plain `<a href="https://wa.me/...">` link with an inline white WhatsApp glyph SVG — no Stimulus controller. Product pages set a `content_for(:whatsapp_lift)` flag that the partial reads to apply a `max-md:bottom-24` lift class so the button clears the existing mobile sticky add-to-cart bar. The admin layout is deliberately not modified, so the button never appears in admin.

**Tech Stack:** Rails (ERB views), Tailwind CSS v4 + DaisyUI (utility classes only, no inline styles), Minitest (`ActionDispatch::IntegrationTest`) with fixtures.

---

## Spec

Implements `docs/superpowers/specs/2026-06-15-sticky-whatsapp-button-design.md`.

## Conventions confirmed in this codebase (read before starting)

- **Test framework is Minitest**, not RSpec. Integration tests live in `test/integration/`, subclass `ActionDispatch::IntegrationTest`, `require "test_helper"`, and use `get <path>`, `assert_response :success`, `assert_match`, `assert_no_match`, and `assert_select`. Run a single file with `bin/rails test test/integration/<file>.rb`.
- **Fixtures:** `products(:one)` is `active: true` with slug `product-1`. The product show route is `product_path("product-1")` (route declared `resources :products, param: :slug`). `ProductsController#show` loads `Product.active...find_by!(slug: params[:slug])`.
- **Admin auth:** admin pages require sign-in via `sign_in_as(users(:acme_admin))`. We do NOT need to render an admin page to prove the button is absent there — asserting the button is absent on a public page that does not include it is not the goal; instead we assert it is present on storefront pages and that the admin layout file does not render the partial. See Task 3.
- **Arbitrary-value Tailwind classes already work here** (e.g. `bg-[#f4fbf8]`, `bg-[#79ebc0]`, `text-[#00a86b]` appear in `app/views/`). So `bg-[#25D366]` will compile. No config change needed.
- **Project rules:** no inline `style` attributes; no `font-bold`/`font-semibold`. This component is icon-only, so the font rule is moot; all colour via utility classes, so the inline-style rule is satisfied.
- **The storefront layout** is `app/views/layouts/application.html.erb`. Around line 108 it renders `shared/confirm_dialog`, then `gcr_store_widget` (line 111) just before `</body>`. We insert the WhatsApp partial between those.
- **The admin layout** `app/views/layouts/admin.html.erb` also renders some `shared/*` partials (e.g. `shared/confirm_dialog`), so "admin is untouched" must be enforced by NOT adding the WhatsApp render there — it will not appear unless explicitly added.

---

## File Structure

- **Create:** `app/views/shared/_whatsapp_button.html.erb` — the floating button markup (anchor + inline SVG + positioning classes). Single responsibility: render the WhatsApp button and decide its lift class from `content_for(:whatsapp_lift)`.
- **Modify:** `app/views/layouts/application.html.erb` — render the partial once near the end of `<body>`.
- **Modify:** `app/views/products/show.html.erb` — set `content_for(:whatsapp_lift, true)` so the button lifts above the mobile add-to-cart bar.
- **Create:** `test/integration/whatsapp_button_test.rb` — integration tests for presence, attributes, the product-page lift, and absence of the lift on non-product pages.

---

### Task 1: Create the WhatsApp button partial and render it in the storefront layout

**Files:**
- Create: `app/views/shared/_whatsapp_button.html.erb`
- Modify: `app/views/layouts/application.html.erb` (insert between the `shared/confirm_dialog` render and `gcr_store_widget`, around line 108-111)
- Test: `test/integration/whatsapp_button_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/integration/whatsapp_button_test.rb`:

```ruby
require "test_helper"

class WhatsappButtonTest < ActionDispatch::IntegrationTest
  test "homepage renders the floating WhatsApp button with correct link and attributes" do
    get root_path

    assert_response :success

    # The wa.me link to the business number with the prefilled message (URL-encoded).
    assert_select "a[href=?]",
      "https://wa.me/447595119603?text=Hi%20Afida%2C%20I%20have%20a%20question%20about" do |links|
      assert_equal 1, links.size, "expected exactly one WhatsApp button on the page"
    end

    # Opens in a new context without leaking the opener.
    assert_select "a[href^='https://wa.me/447595119603'][target='_blank']"
    assert_select "a[href^='https://wa.me/447595119603'][rel~='noopener']"

    # Accessible name for screen readers.
    assert_select "a[href^='https://wa.me/447595119603'][aria-label='Chat with us on WhatsApp']"

    # Inline SVG glyph is present inside the link.
    assert_select "a[href^='https://wa.me/447595119603'] svg"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/integration/whatsapp_button_test.rb`
Expected: FAIL — the assertion `assert_select "a[href=?]", ...` finds 0 matching links (the partial does not exist yet and is not rendered).

- [ ] **Step 3: Create the partial**

Create `app/views/shared/_whatsapp_button.html.erb` with the exact content below. The `lift_class` lifts the button above the mobile add-to-cart bar only when a page sets `content_for(:whatsapp_lift)`. The SVG path is the canonical WhatsApp glyph (Simple Icons), recoloured white via `fill="currentColor"` + `text-white`.

```erb
<%#
  Floating WhatsApp button (storefront-wide).
  Rendered once from app/views/layouts/application.html.erb.

  On product pages, content_for(:whatsapp_lift, true) raises the button above the
  mobile sticky add-to-cart bar so the two never overlap on phones.
%>
<% lift_class = content_for?(:whatsapp_lift) ? "max-md:bottom-24" : "" %>
<a href="https://wa.me/447595119603?text=<%= url_encode("Hi Afida") %>"
   <%# NOTE: Task 2b replaces this literal with a `message` variable built from a base + optional suffix %>
   target="_blank"
   rel="noopener"
   aria-label="Chat with us on WhatsApp"
   title="Chat with us on WhatsApp"
   class="btn btn-circle border-none bg-[#25D366] hover:bg-[#25D366] text-white shadow-lg fixed bottom-5 right-5 z-40 w-16 h-16 hover:scale-105 transition-transform <%= lift_class %>">
  <svg role="img" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="currentColor" class="w-8 h-8">
    <title>WhatsApp</title>
    <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z"/>
  </svg>
</a>
```

Notes for the implementer:
- `url_encode` is a Rails view helper (alias of `ERB::Util.url_encode`) and encodes the message as `Hi%20Afida%2C%20I%20have%20a%20question%20about` (space → `%20`, comma → `%2C`). This exactly matches the test's expected href.
- `btn btn-circle` is DaisyUI; `w-16 h-16` forces 64px (overriding the default `btn-circle` size). `border-none` removes DaisyUI's default button border. `hover:bg-[#25D366]` keeps the green on hover (so only the `scale` animates, the colour doesn't shift).
- No inline `style` attribute is used (project rule). No bold/semibold (project rule).

- [ ] **Step 4: Render the partial in the storefront layout**

In `app/views/layouts/application.html.erb`, find this block near the end of `<body>` (around lines 107-111):

```erb
    <%# Beautiful Turbo Confirm Dialog %>
    <%= render "shared/confirm_dialog" %>

    <%# Google Customer Reviews store widget (shows store rating badge) %>
    <%= gcr_store_widget %>
```

Insert the WhatsApp render between the confirm dialog and the GCR widget so it reads:

```erb
    <%# Beautiful Turbo Confirm Dialog %>
    <%= render "shared/confirm_dialog" %>

    <%# Floating WhatsApp button (storefront-wide) %>
    <%= render "shared/whatsapp_button" %>

    <%# Google Customer Reviews store widget (shows store rating badge) %>
    <%= gcr_store_widget %>
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/integration/whatsapp_button_test.rb`
Expected: PASS (1 run, all assertions pass).

- [ ] **Step 6: Commit**

```bash
git add app/views/shared/_whatsapp_button.html.erb app/views/layouts/application.html.erb test/integration/whatsapp_button_test.rb
git commit -m "Add sitewide floating WhatsApp button"
```

---

### Task 2: Lift the button above the mobile add-to-cart bar on product pages

**Files:**
- Modify: `app/views/products/show.html.erb` (add a `content_for` near the top, alongside the existing `content_for :title` / `:meta_description` blocks at lines 9-15)
- Test: `test/integration/whatsapp_button_test.rb` (add cases)

- [ ] **Step 1: Write the failing tests**

Add these two tests inside `class WhatsappButtonTest` in `test/integration/whatsapp_button_test.rb`:

```ruby
  test "product page lifts the WhatsApp button above the mobile add-to-cart bar" do
    get product_path(products(:one).slug)

    assert_response :success
    # The lift class is applied so the button clears the mobile sticky add-to-cart bar.
    assert_select "a[href^='https://wa.me/447595119603'].max-md\\:bottom-24"
  end

  test "non-product pages do not apply the lift class" do
    get root_path

    assert_response :success
    assert_select "a[href^='https://wa.me/447595119603']"
    assert_select "a[href^='https://wa.me/447595119603'].max-md\\:bottom-24", false,
      "homepage should not lift the WhatsApp button (no add-to-cart bar there)"
  end
```

Note: in a CSS selector the `:` in `max-md:bottom-24` must be escaped as `\\:` (Ruby string → `\:` in the selector). Nokogiri's `assert_select` matches the literal class token.

- [ ] **Step 2: Run tests to verify the lift test fails**

Run: `bin/rails test test/integration/whatsapp_button_test.rb`
Expected: the "product page lifts..." test FAILS (the product page does not yet set `content_for(:whatsapp_lift)`, so the `max-md:bottom-24` class is absent). The "non-product pages do not apply the lift class" test should already PASS.

- [ ] **Step 3: Set the lift flag on the product show page**

In `app/views/products/show.html.erb`, the top of the file (lines 9-15) currently has:

```erb
<% content_for :title do %>
<%= @product.meta_title.presence || @product.generated_meta_title %>
<% end %>

<% content_for :meta_description do %>
<%= @product.meta_description.presence || @product.generated_meta_description %>
<% end %>
```

Immediately after that `:meta_description` block, add:

```erb
<%# Lift the floating WhatsApp button above the mobile sticky add-to-cart bar %>
<% content_for :whatsapp_lift, true %>
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/integration/whatsapp_button_test.rb`
Expected: PASS (3 runs total across Task 1 + Task 2, all assertions pass).

- [ ] **Step 5: Commit**

```bash
git add app/views/products/show.html.erb test/integration/whatsapp_button_test.rb
git commit -m "Lift WhatsApp button above mobile add-to-cart bar on product pages"
```

---

### Task 2b: Prefill the WhatsApp message with product name + SKU on product pages

Added after initial review. Two related decisions came out of that review:
1. The base message must not assume the sender's intent (they may have a question, a
   compliment, an order chase). So the generic message is the bare greeting `Hi Afida`.
2. On a product page, give the lead context by referencing the product as a topic (not an
   intent), using `re:`. Result: `Hi Afida, re: <name> (<SKU>)`, e.g.
   "Hi Afida, re: 8oz White Single Wall Cups (CUP-8OZ-WHT)".

**Mechanism:** a second `content_for(:whatsapp_message_suffix)` hook. The partial builds
the message as the base string (`Hi Afida`) plus the suffix when present, appended FLUSH
(the suffix carries its own leading `, `). The product show page sets the suffix to
`", re: #{@product.generated_title} (#{@product.sku})"`. (`generated_title` and `sku` are
the same attributes the show page already renders.)

**Files:**
- Modify: `app/views/shared/_whatsapp_button.html.erb`
- Modify: `app/views/products/show.html.erb`
- Test: `test/integration/whatsapp_button_test.rb`

- [ ] **Step 1: Write the failing test**

Add inside `class WhatsappButtonTest`. Note: in an integration test `url_encode` is not
mixed in, so reference `ERB::Util.url_encode` (what the view helper delegates to):

```ruby
  test "product page prefills the WhatsApp message with the product name and SKU" do
    product = products(:one)
    get product_path(product.slug)

    assert_response :success

    expected_message = "Hi Afida, re: #{product.generated_title} (#{product.sku})"
    expected_href = "https://wa.me/447595119603?text=#{ERB::Util.url_encode(expected_message)}"

    assert_select "a[href=?]", expected_href do |links|
      assert_equal 1, links.size, "expected the product-specific WhatsApp link"
    end
  end
```

- [ ] **Step 2: Run to verify it fails**

Run: `bin/rails test test/integration/whatsapp_button_test.rb`
Expected: the new test FAILS (product page still renders the generic message).

- [ ] **Step 3: Build the message from base + optional suffix in the partial**

In `app/views/shared/_whatsapp_button.html.erb`, in the leading ERB block, after
`button_classes`, build the message and use it in the href:

```erb
  message = "Hi Afida"
  message = "#{message}#{content_for(:whatsapp_message_suffix)}" if content_for?(:whatsapp_message_suffix)
```

Then change the href to use `message` instead of the literal from Task 1:

```erb
<a href="https://wa.me/447595119603?text=<%= url_encode(message) %>"
```

- [ ] **Step 4: Set the suffix on the product show page**

In `app/views/products/show.html.erb`, after the `content_for :whatsapp_lift` line, add:

```erb
<%# Prefill the WhatsApp message with this product's name and SKU so the lead arrives with context %>
<% content_for :whatsapp_message_suffix, ", re: #{@product.generated_title} (#{@product.sku})" %>
```

- [ ] **Step 5: Run to verify it passes**

Run: `bin/rails test test/integration/whatsapp_button_test.rb`
Expected: PASS. The homepage test (which asserts the exact generic href) must still pass,
proving non-product pages are unaffected.

- [ ] **Step 6: Commit**

```bash
git add app/views/shared/_whatsapp_button.html.erb app/views/products/show.html.erb test/integration/whatsapp_button_test.rb
git commit -m "Prefill WhatsApp message with product name and SKU on product pages"
```

---

### Task 3: Confirm the button is absent from the admin layout

This task adds a guard test so a future change that moves the render into a shared admin-and-storefront partial doesn't accidentally surface the button in admin. The admin layout is a separate file and is not modified.

**Files:**
- Test: `test/integration/whatsapp_button_test.rb` (add one case)

- [ ] **Step 1: Write the test**

Add this test inside `class WhatsappButtonTest`:

```ruby
  test "admin pages do not render the WhatsApp button" do
    sign_in_as(users(:acme_admin))
    get admin_path # /admin index (admin/products#index); helper is admin_path, not admin_root_path

    assert_response :success
    assert_select "a[href^='https://wa.me/447595119603']", false,
      "the WhatsApp button must not appear in the admin area"
  end
```

- [ ] **Step 2: Verify the admin sign-in helper and route**

`sign_in_as` is NOT a shared helper — each test file defines its own. Add the private helper to this test file (shown above), copied from the established pattern in `test/integration/admin_order_pricing_display_test.rb:59`:

```ruby
  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
    follow_redirect!
  end
```

The `acme_admin` fixture has `role: admin` and password `"password"`. The admin index route's helper is `admin_path` (route: `GET /admin → admin/products#index`), NOT `admin_root_path`. Confirm with:

Run: `bin/rails runner "puts Rails.application.routes.url_helpers.admin_path"`
Expected: prints `/admin`.

- [ ] **Step 3: Run the test to verify it passes**

Run: `bin/rails test test/integration/whatsapp_button_test.rb`
Expected: PASS — the admin layout does not render the partial, so 0 WhatsApp links are found. (This passes immediately because we never added the render to the admin layout; the test is a regression guard.)

- [ ] **Step 4: Run the full integration test file once more**

Run: `bin/rails test test/integration/whatsapp_button_test.rb`
Expected: PASS (4 runs, all assertions).

- [ ] **Step 5: Commit**

```bash
git add test/integration/whatsapp_button_test.rb
git commit -m "Guard against WhatsApp button leaking into admin area"
```

---

## Manual verification (after all tasks)

1. Start the app (`bin/dev` or the project's run command).
2. Load the homepage: a green circular WhatsApp button sits at the bottom-right; clicking it opens `wa.me/447595119603` with the message prefilled.
3. Load a product page on a narrow viewport (mobile): scroll until the sticky add-to-cart bar slides up; confirm the WhatsApp button sits above it, not overlapping. On desktop width the button sits at the normal bottom-right offset.
4. Load an admin page: no WhatsApp button.

## Self-review notes (coverage against spec)

- Round 64px green button, white glyph, shadow, hover scale — Task 1 partial.
- `wa.me/447595119603` + prefilled `Hi Afida` (generic) / `Hi Afida, re: <name> (<SKU>)` (product), new tab, `rel=noopener`, `aria-label` — Task 1 + Task 2b markup + tests.
- Inline SVG (single source of truth, no separate file) — Task 1 partial.
- Rendered once in storefront layout, admin untouched — Task 1 + Task 3.
- Product-page lift above the mobile add-to-cart bar via `content_for` flag, absent elsewhere — Task 2.
- No inline styles, no bold/semibold — satisfied by utility-class-only, icon-only markup.
- TDD red→green→commit per task — every task.
