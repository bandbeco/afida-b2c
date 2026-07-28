# On-Site Checkout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Checkout happens on afida.com (order summary, email, address, promo code, Stripe payment inputs) instead of redirecting to Stripe's hosted page, behind an ENV flag with instant hosted fallback.

**Architecture:** `Checkout::SessionBuilder` gains a `:custom` ui_mode; `CheckoutsController#create` (flag on) stashes the session's client secret + a cart fingerprint in the Rails session and 303-redirects to `GET /checkout`, which renders the page. Stripe.js's checkout SDK (`initCheckout`) binds the page to the session; Stripe stays the money-math authority. Spec: `docs/superpowers/specs/2026-07-28-onsite-checkout-design.md`. ADR: `docs/adr/0001-onsite-checkout-on-checkout-sessions.md`.

**Tech Stack:** Rails 8.1, stripe gem 19.3 (API `2025-12-15.clover`), Vite + Stimulus 3, Tailwind/daisyUI, Minitest + Mocha (`StripeTestHelper`), Selenium system tests.

**Branch:** all work on `onsite-checkout`. One commit per task, no Co-Authored-By lines.

**Conventions you must follow:**
- TDD: write the failing test, run it, watch it fail, implement, watch it pass, commit.
- Stripe is stubbed with Mocha at the Ruby class level (never WebMock). Look at `test/support/stripe_test_helper.rb` before writing any Stripe stub; reuse its builders.
- Tests can't write `session[]` directly; set the delivery postcode via `post delivery_postcode_cart_path, params: { delivery_postcode: "WD18 9SB" }` (helper `set_delivery_postcode` already exists in `test/controllers/checkouts_controller_test.rb`).
- Run a focused file with `bin/rails test test/path/file_test.rb`; the full suite with `bin/rails test`.

---

## File structure

| File | Responsibility |
|---|---|
| Create `app/models/onsite_checkout.rb` | The feature flag, read live from ENV |
| Modify `app/services/checkout/session_builder.rb` | `ui_mode:`/`return_url:` keywords; custom-mode params; expose priced zone on `Result` |
| Create `app/controllers/shipping_zones_controller.rb` | Read-only postcode→zone JSON endpoint for the zone guard |
| Create `app/services/checkout/cart_fingerprint.rb` | Staleness fingerprint (cart items + postcode + discount code) |
| Modify `app/controllers/checkouts_controller.rb` | Flag branch in `#create` (stash + PRG); real `#show` action |
| Modify `config/routes.rb` | `resource :shipping_zone, only: :show` |
| Replace `app/views/checkouts/show.html.erb` (currently 0 bytes) | The checkout page |
| Create `app/views/checkouts/_summary.html.erb` | Order summary with Stimulus money-line targets |
| Create `app/frontend/javascript/controllers/onsite_checkout_controller.js` | All SDK wiring: mount, email, totals, promo, zone guard, confirm |
| Modify `app/frontend/entrypoints/application.js` | Lazy-register `onsite-checkout` |
| Modify `config/initializers/content_security_policy.rb` | Stripe hosts |
| Modify `config/initializers/stripe.rb` (or wherever `Rails.configuration.stripe` is built) | Ensure `publishable_key` is exposed |
| Modify `docs/developer_guide.md` | Rewrite stale "Checkout & Orders" section |
| Test files | `test/models/onsite_checkout_test.rb`, `test/services/checkout/cart_fingerprint_test.rb`, `test/controllers/shipping_zones_controller_test.rb`, additions to `test/services/checkout/session_builder_test.rb` and `test/controllers/checkouts_controller_test.rb`, `test/system/onsite_checkout_page_test.rb` |

---

### Task 1: OnsiteCheckout flag

**Files:**
- Create: `app/models/onsite_checkout.rb`
- Test: `test/models/onsite_checkout_test.rb`

The flag must read ENV **at call time** (no constant memoization) so ops can flip it with an env change + redeploy and tests can stub it.

- [x] **Step 1: Write the failing test**

```ruby
# test/models/onsite_checkout_test.rb
require "test_helper"

class OnsiteCheckoutTest < ActiveSupport::TestCase
  test "disabled when ONSITE_CHECKOUT is unset" do
    ENV.stubs(:[]).with("ONSITE_CHECKOUT").returns(nil)
    assert_not OnsiteCheckout.enabled?
  end

  test "enabled for truthy values" do
    %w[true 1].each do |value|
      ENV.stubs(:[]).with("ONSITE_CHECKOUT").returns(value)
      assert OnsiteCheckout.enabled?, "expected #{value.inspect} to enable"
    end
  end

  test "disabled for falsy or junk values" do
    [ "false", "0", "", "banana" ].each do |value|
      ENV.stubs(:[]).with("ONSITE_CHECKOUT").returns(value)
      assert_not OnsiteCheckout.enabled?, "expected #{value.inspect} to disable"
    end
  end
end
```

- [x] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/onsite_checkout_test.rb`
Expected: FAIL / error with `NameError: uninitialized constant OnsiteCheckout`

- [x] **Step 3: Write minimal implementation**

```ruby
# app/models/onsite_checkout.rb
#
# Whether checkout renders on afida.com (Stripe custom UI) instead of
# redirecting to Stripe's hosted page. Read from ENV on every call, not into a
# constant, so flipping back to hosted is an env change + redeploy with no code
# edit — the rollback lever the spec promises.
class OnsiteCheckout
  TRUTHY = %w[true 1].freeze

  def self.enabled?
    TRUTHY.include?(ENV["ONSITE_CHECKOUT"].to_s.strip.downcase)
  end
end
```

- [x] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/models/onsite_checkout_test.rb`
Expected: PASS (3 runs, 0 failures)

- [x] **Step 5: Commit**

```bash
git add app/models/onsite_checkout.rb test/models/onsite_checkout_test.rb
git commit -m "Add OnsiteCheckout flag read live from ENV"
```

---

### Task 2: SessionBuilder custom mode

**Files:**
- Modify: `app/services/checkout/session_builder.rb`
- Test: `test/services/checkout/session_builder_test.rb`

Custom mode differs from hosted in EXACTLY three ways: `ui_mode: "custom"` + `return_url` (replacing `success_url`/`cancel_url`), and `payment_method_types: ["card", "link"]` (wallets ride on card inside the Payment Element). Everything else — line items with the prepended taxed shipping line, zone resolution, metadata, discount branches, `allow_promotion_codes`, customer details, `Result` signalling — must be shared by construction. Also expose the priced zone on `Result` so the controller can stash it without re-deriving.

The existing test file's helpers (`build_session`, `build_stripe_session`, `stub_stripe_tax_rate_list`) are the idiom; read its first ~60 lines before starting.

- [x] **Step 1: Write the failing tests**

Add to `test/services/checkout/session_builder_test.rb` (inside the existing class, reusing its `setup`):

```ruby
  # --- custom (on-site) mode ---

  # Build via the same private helper the file already uses, but in custom mode.
  # If the file's build_session helper doesn't take extra kwargs, extend it to
  # pass ui_mode:/return_url: through to Checkout::SessionBuilder.new.
  def build_custom_session(**kwargs)
    build_session(ui_mode: :custom, return_url: "https://example.com/checkout/success?session_id={CHECKOUT_SESSION_ID}", **kwargs)
  end

  test "custom mode differs from hosted only in ui_mode, URLs, and payment methods" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured = []
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured << params
      true
    end.returns(build_stripe_session)

    build_session
    build_custom_session

    hosted, custom = captured

    assert_equal "custom", custom[:ui_mode]
    assert_equal "https://example.com/checkout/success?session_id={CHECKOUT_SESSION_ID}", custom[:return_url]
    assert_nil custom[:success_url]
    assert_nil custom[:cancel_url]
    assert_equal [ "card", "link" ], custom[:payment_method_types]

    # Everything else must be identical — this is the parity contract the
    # hosted fallback depends on. Shipping line item drift here costs money.
    mode_keys = [ :ui_mode, :return_url, :success_url, :cancel_url, :payment_method_types ]
    assert_equal hosted.except(*mode_keys), custom.except(*mode_keys)
  end

  test "custom mode pins the shipping line item exactly as hosted does" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_custom_session(delivery_postcode: "IV51 9XX")

    shipping_line = captured_params[:line_items].first
    assert_equal Shipping::LINE_ITEM_FLAG, shipping_line[:price_data][:product_data][:metadata]
    assert_equal Shipping.cost_for_zone(:highlands), shipping_line[:price_data][:unit_amount]
    assert_equal "highlands", captured_params[:metadata][:shipping_zone]
  end

  test "custom mode keeps allow_promotion_codes on the no-code path" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_custom_session

    assert_equal true, captured_params[:allow_promotion_codes]
  end

  test "result exposes the priced zone" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)
    Stripe::Checkout::Session.stubs(:create).returns(build_stripe_session)

    assert_equal :highlands, build_session(delivery_postcode: "IV51 9XX").zone
    assert_equal :mainland, build_session(delivery_postcode: "WD18 9SB").zone
  end
```

Note on `build_session`: the existing helper takes kwargs like `discount_code:`/`delivery_postcode:` and forwards to `Checkout::SessionBuilder.new`. Extend its signature to also forward `ui_mode:` and `return_url:` (defaulting so every existing call is untouched).

- [x] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/checkout/session_builder_test.rb`
Expected: new tests FAIL (`unknown keyword: :ui_mode` and `NoMethodError: undefined method 'zone'`); ALL existing tests still PASS.

- [x] **Step 3: Implement**

In `app/services/checkout/session_builder.rb`:

```ruby
    Result = Struct.new(:session, :invalid_discount_code, :selected_address_id, :zone, keyword_init: true) do
      def invalid_discount?
        invalid_discount_code.present?
      end
    end
```

Constructor — add the two keywords (hosted default keeps every existing caller working):

```ruby
    def initialize(cart:, user:, address_id:, discount_code:, datafast_visitor_id:, datafast_session_id:, success_url:, cancel_url:, delivery_postcode: nil, ui_mode: :hosted, return_url: nil)
      @cart = cart
      @user = user
      @address_id = address_id
      @discount_code = discount_code
      @delivery_postcode = delivery_postcode
      @datafast_visitor_id = datafast_visitor_id
      @datafast_session_id = datafast_session_id
      @success_url = success_url
      @cancel_url = cancel_url
      @ui_mode = ui_mode
      @return_url = return_url
    end
```

`create` — add `zone: zone` to the `Result.new` call:

```ruby
      Result.new(
        session: Stripe::Checkout::Session.create(session_params),
        invalid_discount_code: invalid_discount_code,
        selected_address_id: selected_address_id,
        zone: zone
      )
```

`build_session_params` — replace the hardcoded mode bits with a merge (the shared core stays in one hash literal so it CANNOT drift between modes):

```ruby
    def build_session_params
      {
        line_items: line_items,
        mode: "payment",
        shipping_address_collection: {
          allowed_countries: Shipping::ALLOWED_COUNTRIES
        },
        metadata: {
          cart_id: cart.id.to_s,
          discount_code: discount_code,
          datafast_visitor_id: datafast_visitor_id,
          datafast_session_id: datafast_session_id,
          # The zone the order was PRICED against, which is not necessarily the
          # zone of the address collected during payment. The order records what
          # the customer was actually charged, so it reads this back rather than
          # re-deriving from the delivered-to postcode.
          shipping_zone: zone.to_s
        }
      }.merge(mode_params)
    end

    # The ONLY params allowed to differ between hosted and custom mode. The
    # custom (on-site) page shows wallets and Link inside the Payment Element;
    # hosted stays card-only exactly as it always was.
    def mode_params
      if ui_mode == :custom
        {
          ui_mode: "custom",
          return_url: return_url,
          payment_method_types: [ "card", "link" ]
        }
      else
        {
          payment_method_types: [ "card" ],
          success_url: success_url,
          cancel_url: cancel_url
        }
      end
    end
```

Add `:ui_mode, :return_url` to the private `attr_reader` list.

- [x] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/checkout/session_builder_test.rb`
Expected: PASS, including all pre-existing tests.

- [x] **Step 5: Run the controller tests too** (they drive the builder through `#create`)

Run: `bin/rails test test/controllers/checkouts_controller_test.rb`
Expected: PASS unchanged.

- [x] **Step 6: Commit**

```bash
git add app/services/checkout/session_builder.rb test/services/checkout/session_builder_test.rb
git commit -m "Teach SessionBuilder a custom ui_mode sharing all core params"
```

---

### Task 3: Shipping-zone endpoint (zone guard, server half)

**Files:**
- Create: `app/controllers/shipping_zones_controller.rb`
- Modify: `config/routes.rb`
- Test: `test/controllers/shipping_zones_controller_test.rb`

- [x] **Step 1: Write the failing test**

```ruby
# test/controllers/shipping_zones_controller_test.rb
require "test_helper"

class ShippingZonesControllerTest < ActionDispatch::IntegrationTest
  test "resolves a mainland postcode" do
    get shipping_zone_path, params: { postcode: "WD18 9SB" }

    assert_response :success
    assert_equal({ "zone" => "mainland", "deliverable" => true }, response.parsed_body)
  end

  test "resolves a highlands postcode" do
    get shipping_zone_path, params: { postcode: "IV51 9XX" }

    assert_equal "highlands", response.parsed_body["zone"]
  end

  test "resolves an outward code alone, as the cart field does" do
    get shipping_zone_path, params: { postcode: "BT1" }

    assert_equal({ "zone" => "northern_ireland", "deliverable" => true }, response.parsed_body)
  end

  test "unparseable postcode is unknown and not deliverable" do
    get shipping_zone_path, params: { postcode: "banana" }

    assert_equal({ "zone" => "unknown", "deliverable" => false }, response.parsed_body)
  end

  test "works logged out" do
    get shipping_zone_path, params: { postcode: "SW1A 1AA" }

    assert_response :success
  end
end
```

- [x] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/shipping_zones_controller_test.rb`
Expected: FAIL with `NameError: undefined local variable or method 'shipping_zone_path'`

- [x] **Step 3: Implement**

In `config/routes.rb`, next to `resource :checkout`:

```ruby
  # Read-only postcode→zone lookup for the on-site checkout's zone guard.
  # Deliberately outside checkout's rate limit: it fires on address keystrokes.
  resource :shipping_zone, only: [ :show ]
```

```ruby
# app/controllers/shipping_zones_controller.rb
#
# The zone guard's server half: resolves a postcode to its shipping zone so the
# on-site checkout page can compare the address being typed against the zone
# the order was priced for. Read-only, session-free, public — it exposes
# nothing the delivery page doesn't already publish.
class ShippingZonesController < ApplicationController
  allow_unauthenticated_access

  def show
    zone = ShippingZone.for(params[:postcode])
    render json: { zone: zone, deliverable: ShippingZone.deliverable?(zone) }
  end
end
```

(If `allow_unauthenticated_access` is not how public controllers opt out in this app, mirror whatever `CheckoutsController` does — it has `allow_unauthenticated_access` at the top.)

- [x] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/controllers/shipping_zones_controller_test.rb`
Expected: PASS (5 runs)

- [x] **Step 5: Commit**

```bash
git add app/controllers/shipping_zones_controller.rb config/routes.rb test/controllers/shipping_zones_controller_test.rb
git commit -m "Add read-only shipping-zone lookup endpoint for the zone guard"
```

---

### Task 4: Cart fingerprint

**Files:**
- Create: `app/services/checkout/cart_fingerprint.rb`
- Test: `test/services/checkout/cart_fingerprint_test.rb`

The staleness fingerprint: same cart items + same postcode + same discount code ⇒ same digest. Any input change ⇒ different digest.

- [x] **Step 1: Write the failing test**

```ruby
# test/services/checkout/cart_fingerprint_test.rb
require "test_helper"

class Checkout::CartFingerprintTest < ActiveSupport::TestCase
  setup do
    @cart = Cart.create!
    @cart.cart_items.create!(product: products(:one), quantity: 2, price: 10.00)
  end

  def digest(cart: @cart, postcode: "WD18 9SB", discount_code: nil)
    Checkout::CartFingerprint.digest(cart: cart, postcode: postcode, discount_code: discount_code)
  end

  test "stable for identical inputs" do
    assert_equal digest, digest
  end

  test "changes when a quantity changes" do
    before = digest
    @cart.cart_items.first.update!(quantity: 3)
    assert_not_equal before, digest
  end

  test "changes when an item is added" do
    before = digest
    @cart.cart_items.create!(product: products(:two), quantity: 1, price: 30.00)
    assert_not_equal before, digest
  end

  test "changes when the postcode changes zone-or-not" do
    assert_not_equal digest(postcode: "WD18 9SB"), digest(postcode: "IV51 9XX")
  end

  test "insensitive to postcode case and whitespace" do
    assert_equal digest(postcode: "WD18 9SB"), digest(postcode: " wd18 9sb ")
  end

  test "changes when the discount code changes" do
    assert_not_equal digest(discount_code: nil), digest(discount_code: "coupon_abc")
  end
end
```

- [x] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/checkout/cart_fingerprint_test.rb`
Expected: FAIL with `NameError: uninitialized constant Checkout::CartFingerprint`

- [x] **Step 3: Implement**

```ruby
# app/services/checkout/cart_fingerprint.rb
module Checkout
  # Staleness fingerprint for a stashed on-site checkout session. The Stripe
  # session freezes line items and shipping price at #create; if the inputs
  # that produced them change before the GET page renders (cart edited in
  # another tab, postcode retyped, discount claimed), the stash must be
  # discarded rather than charged. Same inputs ⇒ same digest.
  class CartFingerprint
    def self.digest(cart:, postcode:, discount_code:)
      payload = {
        items: cart.cart_items.order(:id).map do |item|
          [ item.id, item.product_id, item.quantity, item.price.to_s, item.sample?, item.configuration ]
        end,
        postcode: postcode.to_s.upcase.strip.squeeze(" "),
        discount_code: discount_code.to_s
      }
      Digest::SHA256.hexdigest(payload.to_json)
    end
  end
end
```

(If `item.sample?` or `item.configuration` doesn't exist on CartItem, check the model — `SessionBuilder#stripe_quantity` calls `item.sample?` and `item.configured?`/`item.configuration["size"]`, so both exist.)

- [x] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/checkout/cart_fingerprint_test.rb`
Expected: PASS (6 runs)

- [x] **Step 5: Commit**

```bash
git add app/services/checkout/cart_fingerprint.rb test/services/checkout/cart_fingerprint_test.rb
git commit -m "Add cart fingerprint for on-site checkout staleness checks"
```

---

### Task 5: `#create` PRG branch (flag on → stash + redirect)

**Files:**
- Modify: `app/controllers/checkouts_controller.rb`
- Test: `test/controllers/checkouts_controller_test.rb`

Flag off: byte-for-byte today's behaviour. Flag on: same guards and events, builder in custom mode, stash `{session_id, client_secret, fingerprint, postcode, zone}` under `session[:onsite_checkout]`, 303 to `checkout_path`.

- [x] **Step 1: Write the failing tests**

Add to `test/controllers/checkouts_controller_test.rb`. The custom-mode Stripe session stub needs a `client_secret`; check `test/support/stripe_test_helper.rb` for `build_stripe_session` — if it doesn't accept overrides, add alongside it:

```ruby
  # test/support/stripe_test_helper.rb — custom-mode session: no redirect URL,
  # has a client secret for the on-site page.
  def build_custom_stripe_session
    stub(
      id: "sess_custom_123",
      url: nil,
      client_secret: "cs_test_secret_abc",
      payment_status: "unpaid"
    )
  end
```

(Mirror whatever attributes `build_stripe_session` stubs — same `stub(...)` style, same id format if tests elsewhere match on it.)

Then the tests:

```ruby
  def enable_onsite_checkout
    ENV.stubs(:[]).returns(nil)                     # keep other ENV reads working
    ENV.stubs(:[]).with("ONSITE_CHECKOUT").returns("true")
  end
```

**Careful:** the blanket `ENV.stubs(:[]).returns(nil)` line above is dangerous if anything else reads ENV during the request (ShippingZone cost overrides do: `ENV.fetch`, which does NOT go through `[]`). Prefer the narrower form — stub only the one key and let everything else through:

```ruby
  def enable_onsite_checkout
    OnsiteCheckout.stubs(:enabled?).returns(true)
  end
```

Use the `OnsiteCheckout.stubs` form. The flag class has its own ENV tests (Task 1); controller tests stub the seam.

```ruby
  # --- on-site checkout (flag on) ---

  test "create with flag on builds a custom-mode session and redirects to the checkout page" do
    enable_onsite_checkout

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_custom_stripe_session)

    post checkout_path

    assert_redirected_to checkout_path
    assert_response :see_other
    assert_equal "custom", captured_params[:ui_mode]
    assert_match %r{/checkout/success\?session_id=\{CHECKOUT_SESSION_ID\}}, captured_params[:return_url]
    assert_nil captured_params[:success_url]

    stash = session[:onsite_checkout]
    assert_equal "sess_custom_123", stash["session_id"]
    assert_equal "cs_test_secret_abc", stash["client_secret"]
    assert_equal "mainland", stash["zone"]
    assert stash["fingerprint"].present?
    assert_equal "WD18 9SB", stash["postcode"]
  end

  test "create with flag on still refuses an empty cart" do
    enable_onsite_checkout
    @cart.cart_items.destroy_all

    post checkout_path

    assert_redirected_to cart_path
    assert_nil session[:onsite_checkout]
  end

  test "create with flag on still refuses an undeliverable destination" do
    enable_onsite_checkout
    set_delivery_postcode("IM1 1AA")   # Isle of Man: undeliverable

    post checkout_path

    assert_redirected_to cart_path
    assert_nil session[:onsite_checkout]
  end

  test "create with flag off never stashes" do
    stub_stripe_session_create

    post checkout_path

    assert_match %r{https://checkout\.stripe\.com}, response.redirect_url
    assert_nil session[:onsite_checkout]
  end
```

- [x] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/checkouts_controller_test.rb`
Expected: the four new tests FAIL (flag-on posts still redirect to checkout.stripe.com; no stash). All existing tests PASS.

- [x] **Step 3: Implement**

In `CheckoutsController#create`, capture the resolved postcode once (it's currently computed inline in the builder call), pass mode params to the builder, and branch the redirect. The builder call becomes:

```ruby
      resolved_postcode = delivery_postcode_for(params[:address_id])

      builder = Checkout::SessionBuilder.new(
        cart: cart,
        user: Current.user,
        address_id: params[:address_id],
        discount_code: session[:discount_code],
        delivery_postcode: resolved_postcode,
        datafast_visitor_id: cookies[:datafast_visitor_id],
        datafast_session_id: cookies[:datafast_session_id],
        success_url: success_checkout_url + "?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: cancel_checkout_url,
        ui_mode: OnsiteCheckout.enabled? ? :custom : :hosted,
        return_url: success_checkout_url + "?session_id={CHECKOUT_SESSION_ID}"
      )
      result = builder.create

      if result.invalid_discount?
        session.delete(:discount_code)
        flash[:alert] = "Your discount code could not be applied. Please continue with your order."
      end

      session[:selected_address_id] = result.selected_address_id if result.selected_address_id.present?

      if OnsiteCheckout.enabled?
        session[:onsite_checkout] = {
          "session_id" => result.session.id,
          "client_secret" => result.session.client_secret,
          "fingerprint" => Checkout::CartFingerprint.digest(
            cart: cart, postcode: resolved_postcode, discount_code: session[:discount_code]
          ),
          "postcode" => resolved_postcode,
          "zone" => result.zone.to_s
        }
        redirect_to checkout_path, status: :see_other
      else
        redirect_to result.session.url, allow_other_host: true, status: :see_other
      end
```

Everything above the builder call (guards, `checkout.started`, `cart.checkout_initiated`, rate limit) is untouched. Note the fingerprint is computed AFTER the invalid-discount cleanup so it uses the post-cleanup `session[:discount_code]` — if the welcome code was invalid and deleted, the fingerprint must reflect no-discount, matching what the Stripe session was actually built without... **No — stop.** The Stripe session was built WITH the attempt and fell back to `allow_promotion_codes`; the GET page's recompute will read the (now deleted) `session[:discount_code]` as nil. Computing the stash fingerprint after the delete makes both sides nil ⇒ they match ⇒ no false bounce. That is why the stash block sits below the invalid-discount cleanup. Keep that ordering.

- [x] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/checkouts_controller_test.rb`
Expected: PASS, new and old.

- [x] **Step 5: Commit**

```bash
git add app/controllers/checkouts_controller.rb test/controllers/checkouts_controller_test.rb test/support/stripe_test_helper.rb
git commit -m "Stash custom checkout session and redirect to GET checkout page"
```

---

### Task 6: `#show` action + page skeleton

**Files:**
- Modify: `app/controllers/checkouts_controller.rb`
- Replace: `app/views/checkouts/show.html.erb` (currently a 0-byte placeholder)
- Create: `app/views/checkouts/_summary.html.erb`
- Test: `test/controllers/checkouts_controller_test.rb`

`GET /checkout` already routes to `checkouts#show` (empty template today, so it renders a blank page). Give it a real action: flag off or no stash → cart; stale fingerprint → discard stash, bounce to cart with notice; otherwise render.

- [x] **Step 1: Write the failing tests**

```ruby
  # --- GET /checkout (on-site page) ---

  def stash_onsite_session
    enable_onsite_checkout
    Stripe::Checkout::Session.stubs(:create).returns(build_custom_stripe_session)
    post checkout_path
    assert_redirected_to checkout_path
  end

  test "show renders the page from a fresh stash" do
    stash_onsite_session

    get checkout_path

    assert_response :success
    assert_match "cs_test_secret_abc", response.body
    assert_select "[data-controller='onsite-checkout']"
    assert_select "[data-onsite-checkout-target='payment']"
    assert_select "[data-onsite-checkout-target='address']"
  end

  test "show redirects to cart when the flag is off" do
    get checkout_path
    assert_redirected_to cart_path
  end

  test "show redirects to cart without a stash" do
    enable_onsite_checkout
    get checkout_path
    assert_redirected_to cart_path
  end

  test "show bounces a stale stash to the cart and discards it" do
    stash_onsite_session

    @cart.cart_items.first.update!(quantity: 5)   # cart changed in "another tab"

    get checkout_path

    assert_redirected_to cart_path
    assert_equal "Your basket changed. Continue to payment when you're ready.", flash[:notice]
    assert_nil session[:onsite_checkout]
  end

  test "show shows the promo control only when no server discount and not samples-only" do
    stash_onsite_session
    get checkout_path
    assert_select "[data-onsite-checkout-target='promoSection']"
  end

  test "invalid welcome coupon renders the alert AND the promo control together" do
    # The spec's pinned combination: #create fell back to allow_promotion_codes
    # and deleted the session discount, so the GET page must show the failure
    # alert while still offering the promo input (the shopper can retype).
    enable_onsite_checkout
    post email_subscriptions_path, params: { email: "promo-test@example.com" }
    Stripe::PromotionCode.stubs(:list).returns(stub(data: []))
    Stripe::Coupon.stubs(:retrieve).raises(Stripe::InvalidRequestError.new("No such coupon", nil))
    Stripe::Checkout::Session.stubs(:create).returns(build_custom_stripe_session)

    post checkout_path
    follow_redirect!

    assert_response :success
    assert_match "Your discount code could not be applied", response.body
    assert_select "[data-onsite-checkout-target='promoSection']"
  end
```

- [x] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/checkouts_controller_test.rb`
Expected: new tests FAIL (`show` currently renders the empty template with 200 for everyone).

- [x] **Step 3: Implement the action**

Add to `CheckoutsController` (above `success`):

```ruby
  # The on-site checkout page. Renders the Stripe session stashed by #create;
  # performs no Stripe writes, so refresh and back-navigation are free.
  def show
    return redirect_to cart_path unless OnsiteCheckout.enabled?

    stash = session[:onsite_checkout]
    cart = Current.cart
    return redirect_to cart_path if stash.blank? || cart.blank? || cart.cart_items.empty?

    postcode = session[:delivery_postcode].presence || stash["postcode"]
    fingerprint = Checkout::CartFingerprint.digest(
      cart: cart, postcode: postcode, discount_code: session[:discount_code]
    )
    if fingerprint != stash["fingerprint"]
      session.delete(:onsite_checkout)
      return redirect_to cart_path, notice: "Your basket changed. Continue to payment when you're ready."
    end

    @client_secret = stash["client_secret"]
    @priced_zone = stash["zone"]
    @show_promo = session[:discount_code].blank? && !cart.only_samples?
    @prefill_address = Current.user&.addresses&.find_by(id: session[:selected_address_id]) ||
                       Current.user&.addresses&.default_first&.first
    @customer_email = Current.user&.email_address
  end
```

(Verify `email_address` vs `email` on User and `default_first` on the addresses association — both appear in existing code: `session_builder.rb` uses `user.email_address`; `application_controller.rb#default_address_postcode` uses `addresses&.default_first&.first`.)

- [x] **Step 4: Implement the view**

`app/views/checkouts/show.html.erb`:

```erb
<% content_for :title, "Checkout | Afida" %>
<% content_for :head do %>
  <script src="https://js.stripe.com/v3/"></script>
<% end %>

<div class="max-w-6xl mx-auto px-4 py-8"
     data-controller="onsite-checkout"
     data-onsite-checkout-client-secret-value="<%= @client_secret %>"
     data-onsite-checkout-publishable-key-value="<%= Rails.configuration.stripe[:publishable_key] %>"
     data-onsite-checkout-priced-zone-value="<%= @priced_zone %>"
     data-onsite-checkout-guest-value="<%= Current.user.blank? %>"
     data-onsite-checkout-prefill-value="<%= {
       name: @prefill_address&.recipient_name,
       line1: @prefill_address&.line1,
       line2: @prefill_address&.line2,
       city: @prefill_address&.city,
       postal_code: @prefill_address&.postcode,
       country: "GB"
     }.compact.to_json %>">

  <h1 class="text-2xl sm:text-3xl mb-6">Checkout</h1>

  <div class="flex flex-col-reverse md:flex-row gap-8">
    <div class="w-full md:w-3/5 space-y-6">

      <section>
        <h2 class="text-lg mb-2">Contact</h2>
        <% if @customer_email %>
          <input type="email" value="<%= @customer_email %>" readonly
                 class="input input-bordered w-full bg-gray-100"
                 data-onsite-checkout-target="email">
        <% else %>
          <input type="email" placeholder="you@example.com" autocomplete="email"
                 class="input input-bordered w-full"
                 data-onsite-checkout-target="email"
                 data-action="blur->onsite-checkout#emailChanged">
        <% end %>
      </section>

      <section>
        <h2 class="text-lg mb-2">Delivery address</h2>
        <div data-onsite-checkout-target="address"></div>
        <p class="text-sm text-error mt-2 hidden" data-onsite-checkout-target="zoneWarning">
          This postcode is in a different delivery zone than your order was priced for.
          <%= link_to "Return to your basket", cart_path, class: "link" %> to update your
          delivery postcode and reprice.
        </p>
      </section>

      <% if @show_promo %>
        <section data-onsite-checkout-target="promoSection">
          <h2 class="text-lg mb-2">Promo code</h2>
          <div class="flex gap-2" data-onsite-checkout-target="promoForm">
            <input type="text" placeholder="Enter code" class="input input-bordered input-sm flex-1"
                   data-onsite-checkout-target="promoInput">
            <button type="button" class="btn btn-sm btn-outline"
                    data-action="onsite-checkout#applyPromo">Apply</button>
          </div>
          <div class="hidden items-center gap-2" data-onsite-checkout-target="promoApplied">
            <span class="badge badge-success" data-onsite-checkout-target="promoCode"></span>
            <button type="button" class="btn btn-xs btn-ghost"
                    data-action="onsite-checkout#removePromo" aria-label="Remove promo code">&times;</button>
          </div>
          <p class="text-xs text-error mt-1 hidden" data-onsite-checkout-target="promoError"></p>
        </section>
      <% end %>

      <section>
        <h2 class="text-lg mb-2">Payment</h2>
        <div data-onsite-checkout-target="payment"></div>
      </section>

      <p class="text-sm text-error hidden" data-onsite-checkout-target="error"></p>

      <button type="button" class="btn btn-primary w-full" disabled
              data-onsite-checkout-target="payButton"
              data-action="onsite-checkout#pay">
        Pay now
      </button>

      <noscript>
        <p class="text-sm text-error">
          Checkout needs JavaScript. <%= link_to "Return to your basket", cart_path, class: "link" %>.
        </p>
      </noscript>
    </div>

    <div class="w-full md:w-2/5">
      <div class="bg-gray-100 p-4 sm:p-6 rounded-lg shadow-md">
        <%= render "checkouts/summary", cart: Current.cart %>
        <p class="mt-4 text-sm"><%= link_to "← Back to basket", cart_path, class: "link" %></p>
      </div>
    </div>
  </div>
</div>
```

`app/views/checkouts/_summary.html.erb` — reuses the cart's line source (`cart_summary_lines`, same as `cart_items/_summary`) but adds Stimulus targets so the SDK can re-render money lines after a promo code changes them:

```erb
<%# On-site checkout order summary. Lines come from cart_summary_lines (the same
    source the cart page uses) for the initial server render; the money values
    carry data targets so the onsite-checkout Stimulus controller re-renders
    them from the Stripe session state (the charging authority) once the SDK is
    live. Line KINDS map to targets; keep the kinds in step with CartSummary. %>
<div id="checkout_summary">
  <h2 class="text-lg sm:text-2xl mb-3 sm:mb-6">Order Summary</h2>

  <% cart_summary_lines(cart).each do |line| %>
    <% if line[:kind] == :total %>
      <div class="flex justify-between text-lg sm:text-xl text-gray-800 border-t pt-3 mt-3">
        <span><%= line[:label] %></span>
        <span data-onsite-checkout-target="totalLine"><%= line[:amount] %></span>
      </div>
    <% else %>
      <div class="flex justify-between mb-2 text-sm sm:text-base <%= line[:negative] ? "text-success" : "text-gray-700" %>">
        <span><%= line[:label] %></span>
        <span data-onsite-checkout-money-kind="<%= line[:kind] %>"><%= line[:amount] %></span>
      </div>
    <% end %>
  <% end %>
</div>
```

(Check `app/helpers` for where `cart_summary_lines` and `cart_summary_line_dom_id` live and what `line[:kind]` values exist — mirror them; do NOT reuse the `#cart_summary` DOM id, which the cart page's Turbo Streams own.)

- [x] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/controllers/checkouts_controller_test.rb`
Expected: PASS.

- [x] **Step 6: Commit**

```bash
git add app/controllers/checkouts_controller.rb app/views/checkouts/show.html.erb app/views/checkouts/_summary.html.erb test/controllers/checkouts_controller_test.rb
git commit -m "Render the on-site checkout page from the stashed session"
```

---

### Task 7: Publishable key + CSP

**Files:**
- Modify: `config/initializers/stripe.rb` (or wherever `Rails.configuration.stripe` is assembled — grep `configuration.stripe` in `config/`)
- Modify: `config/initializers/content_security_policy.rb`

Nothing client-side ever needed the publishable key before (hosted checkout is a redirect), so it may not be wired.

- [x] **Step 1: Check and wire the publishable key**

Run: `grep -rn "publishable" config/ app/ | grep -v node_modules`

If `Rails.configuration.stripe[:publishable_key]` is not populated, add it where the stripe config hash is built (same pattern as `secret_key`, sourced from credentials — see `docs/runbooks/credentials.md` for the vault; sandbox and live keys differ). If the credentials key is missing, add it via `bin/rails credentials:edit` per the runbook and note it in the PR description.

- [x] **Step 2: Assert it in a test**

Add to `test/controllers/checkouts_controller_test.rb`'s "show renders the page from a fresh stash" test:

```ruby
    assert_select "[data-onsite-checkout-publishable-key-value]" do |elements|
      assert elements.first["data-onsite-checkout-publishable-key-value"].present?,
        "publishable key must reach the page"
    end
```

Run: `bin/rails test test/controllers/checkouts_controller_test.rb` — PASS (fix config until it does).

- [x] **Step 3: CSP additions**

In `config/initializers/content_security_policy.rb` (currently report-only, so this can't break production, but must be right before the flag flips):

```ruby
    policy.script_src :self,
                      :unsafe_inline,
                      :unsafe_eval,
                      "https://js.stripe.com",
                      ... (existing entries unchanged)

    policy.connect_src :self,
                       "https://api.stripe.com",
                       ... (existing entries unchanged)

    policy.frame_src :self,
                     "https://js.stripe.com",
                     "https://hooks.stripe.com",
                     ... (existing entries unchanged)
```

(Per Stripe's CSP documentation for Stripe.js/Elements: `script-src js.stripe.com`, `frame-src js.stripe.com hooks.stripe.com`, `connect-src api.stripe.com`. Verify against https://docs.stripe.com/security/guide#content-security-policy at implementation time and add any host the report-only console flags on staging.)

- [x] **Step 4: Commit**

```bash
git add config/initializers/content_security_policy.rb config/initializers/stripe.rb test/controllers/checkouts_controller_test.rb
git commit -m "Expose Stripe publishable key and allow Stripe hosts in CSP"
```

---

### Task 8: Stimulus controller (SDK wiring)

**Files:**
- Create: `app/frontend/javascript/controllers/onsite_checkout_controller.js`
- Modify: `app/frontend/entrypoints/application.js` (lazy-register)

No JS test framework exists in this repo; this task is verified by Task 9's system test (markup + controller connects) and the staging checklist (real payments). Keep ALL SDK knowledge in this one file.

**API verification step is part of this task:** the code below targets Stripe.js's checkout SDK ("Elements with Checkout Sessions API", `stripe.initCheckout`) as documented at https://docs.stripe.com/checkout/custom/quickstart and https://docs.stripe.com/js/custom_checkout. Before writing, open those pages and verify these exact names: `initCheckout`, `createPaymentElement`, `createShippingAddressElement`, `session()`, `on("change")`, `updateEmail`, `applyPromotionCode`, `removePromotionCode`, `confirm`, and the shape of `session.total`. Where a name differs, follow the docs — the structure below stands.

- [x] **Step 1: Write the controller**

```js
// app/frontend/javascript/controllers/onsite_checkout_controller.js
import { Controller } from "@hotwired/stimulus"

// On-site checkout: binds the page to a Stripe Checkout Session (ui_mode:
// "custom") created server-side. Stripe's SDK owns the money math; this
// controller mounts the secure elements, mirrors session totals into the
// summary, applies/removes promo codes, guards the shipping zone, and confirms.
export default class extends Controller {
  static targets = [
    "email", "address", "payment", "payButton", "error",
    "totalLine", "zoneWarning",
    "promoSection", "promoForm", "promoInput", "promoApplied", "promoCode", "promoError"
  ]

  static values = {
    clientSecret: String,
    publishableKey: String,
    pricedZone: String,
    guest: Boolean,
    prefill: Object
  }

  async connect() {
    this.zoneOk = true
    this.currency = new Intl.NumberFormat("en-GB", { style: "currency", currency: "GBP" })

    if (!window.Stripe) return this.fatal()

    try {
      this.stripe = Stripe(this.publishableKeyValue)
      this.checkout = await this.stripe.initCheckout({
        fetchClientSecret: async () => this.clientSecretValue
      })
    } catch (error) {
      console.error("[onsite-checkout] init failed:", error)
      return this.fatal()
    }

    this.checkout.createPaymentElement().mount(this.paymentTarget)

    const addressOptions = Object.keys(this.prefillValue || {}).length
      ? { defaultValues: this.prefillValue }
      : {}
    this.checkout.createShippingAddressElement(addressOptions).mount(this.addressTarget)

    this.checkout.on("change", (session) => this.sessionChanged(session))
    this.sessionChanged(this.checkout.session())
    this.payButtonTarget.disabled = false
  }

  // --- session state → page ---

  sessionChanged(session) {
    this.renderTotals(session)
    this.guardZone(session)
  }

  renderTotals(session) {
    // session.total amounts are in minor units (pence). Update the grand total
    // always; per-kind lines update when the session exposes a matching amount.
    // Verify the exact session.total shape against the SDK docs (see task
    // header); adjust ONLY the mapping below if key names differ.
    if (session?.total?.total != null) {
      this.totalLineTarget.textContent = this.currency.format(session.total.total / 100)
    }
    const kinds = {
      subtotal: session?.total?.subtotal,
      discount: session?.total?.discount,
      vat: session?.total?.taxExclusive
    }
    for (const [kind, amount] of Object.entries(kinds)) {
      if (amount == null) continue
      const el = this.element.querySelector(`[data-onsite-checkout-money-kind='${kind}']`)
      if (el) el.textContent = this.currency.format(amount / 100)
    }
  }

  // --- zone guard (best-effort; any failure fails open) ---

  guardZone(session) {
    const postcode = session?.shippingAddress?.address?.postal_code
    if (!postcode) return

    clearTimeout(this.zoneTimer)
    this.zoneTimer = setTimeout(() => this.checkZone(postcode), 400)
  }

  async checkZone(postcode) {
    try {
      const response = await fetch(`/shipping_zone?postcode=${encodeURIComponent(postcode)}`)
      if (!response.ok) return
      const { zone } = await response.json()
      this.zoneOk = zone === this.pricedZoneValue
    } catch {
      this.zoneOk = true // fail open: no worse than hosted checkout today
    }
    this.zoneWarningTarget.classList.toggle("hidden", this.zoneOk)
    this.payButtonTarget.disabled = !this.zoneOk
  }

  // --- email (guests only; logged-in email is read-only and already on the session) ---

  async emailChanged() {
    if (!this.guestValue) return
    const email = this.emailTarget.value.trim()
    if (!email) return
    try {
      await this.checkout.updateEmail(email)
    } catch (error) {
      this.showError("Please check your email address.")
    }
  }

  // --- promo codes ---

  async applyPromo() {
    const code = this.promoInputTarget.value.trim()
    if (!code) return
    this.promoErrorTarget.classList.add("hidden")
    const result = await this.checkout.applyPromotionCode(code)
    if (result?.error) {
      this.promoErrorTarget.textContent = result.error.message || "That code didn't work."
      this.promoErrorTarget.classList.remove("hidden")
      return
    }
    this.promoCodeTarget.textContent = code.toUpperCase()
    this.promoFormTarget.classList.add("hidden")
    this.promoAppliedTarget.classList.remove("hidden")
    this.promoAppliedTarget.classList.add("flex")
  }

  async removePromo() {
    await this.checkout.removePromotionCode()
    this.promoAppliedTarget.classList.add("hidden")
    this.promoAppliedTarget.classList.remove("flex")
    this.promoFormTarget.classList.remove("hidden")
    this.promoInputTarget.value = ""
  }

  // --- confirm ---

  async pay() {
    if (!this.zoneOk) return
    this.payButtonTarget.disabled = true
    this.errorTarget.classList.add("hidden")

    const result = await this.checkout.confirm()
    // On success Stripe redirects to return_url; we only come back here on error.
    if (result?.error) {
      this.showError(result.error.message || "Payment failed. Please try again.")
      this.payButtonTarget.disabled = false
    }
  }

  // --- errors ---

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  fatal() {
    this.showError("Checkout couldn't load. Please refresh, or return to your basket and try again.")
  }
}
```

- [x] **Step 2: Register it lazily**

In `app/frontend/entrypoints/application.js`, add to the `lazyControllers` map (alphabetical position, matching the file's style):

```js
  "onsite-checkout": () => import("../javascript/controllers/onsite_checkout_controller"),
```

- [x] **Step 3: Verify the build**

Run: `bin/vite build` (or `bin/dev` and load any page watching the console)
Expected: build succeeds, no import errors.

- [x] **Step 4: Commit**

```bash
git add app/frontend/javascript/controllers/onsite_checkout_controller.js app/frontend/entrypoints/application.js
git commit -m "Wire the on-site checkout page to Stripe's checkout SDK"
```

---

### Task 9: System test

**Files:**
- Create: `test/system/onsite_checkout_page_test.rb`

Per the spec: assert the page renders with summary, mount points, and promo control. Do NOT drive the real Stripe iframe in CI (flaky by design); confirm-and-pay is the staging checklist's job. System tests run the app in-process, so Mocha stubs apply.

- [x] **Step 1: Write the test**

```ruby
# test/system/onsite_checkout_page_test.rb
require "application_system_test_case"

class OnsiteCheckoutPageTest < ApplicationSystemTestCase
  setup do
    OnsiteCheckout.stubs(:enabled?).returns(true)
    Stripe::TaxRate.stubs(:list).returns(stub(data: [ stub(id: "txr_test", percentage: 20.0) ]))
    Stripe::Checkout::Session.stubs(:create).returns(
      stub(id: "sess_custom_sys", url: nil, client_secret: "cs_test_secret_sys", payment_status: "unpaid")
    )
  end

  test "checkout page renders summary, mount points, and promo control" do
    visit product_path(products(:one))          # adjust to the real product path helper
    click_on "Add to cart"                       # adjust to the real button label
    visit cart_path
    fill_in "Delivery postcode", with: "WD18 9SB"
    click_on "Calculate shipping"
    click_on "Checkout"                          # adjust to the real checkout button label

    assert_current_path checkout_path
    assert_selector "#checkout_summary"
    assert_selector "[data-onsite-checkout-target='payment']"
    assert_selector "[data-onsite-checkout-target='address']"
    assert_selector "[data-onsite-checkout-target='promoSection']"
    assert_selector "[data-onsite-checkout-target='payButton']"
    assert_link "Back to basket"
  end
end
```

Before running: open the cart page views to confirm the real labels for the add-to-cart and checkout buttons and the product path helper, and adjust the three marked lines. If `StripeTestHelper` works in system tests (it's included via `test/support`), prefer `stub_stripe_tax_rate_list` + `build_custom_stripe_session` over the inline stubs above.

- [x] **Step 2: Run it**

Run: `bin/rails test:system test/system/onsite_checkout_page_test.rb`
Expected: PASS. (The Stimulus controller will attempt `initCheckout` against the fake secret and fail in the browser console — the test only asserts server-rendered markup, so that's fine.)

- [x] **Step 3: Run the full suite**

Run: `bin/rails test && bin/rails test:system`
Expected: PASS across the board.

- [x] **Step 4: Commit**

```bash
git add test/system/onsite_checkout_page_test.rb
git commit -m "Add system test for the on-site checkout page render"
```

---

### Task 10: Developer guide + rollout checklist

**Files:**
- Modify: `docs/developer_guide.md` (the "Checkout & Orders" section, ~lines 282–360)

- [x] **Step 1: Rewrite the stale section**

The current section shows a `shipping_options`-based flow (£4.99/£9.99) that predates zones and doesn't match `Checkout::SessionBuilder`. Replace it with an accurate description covering: `Checkout::SessionBuilder` (line items with the prepended taxed shipping line, `ShippingZone` pricing from the cart-page postcode, discounts via promotion-code resolution, `allow_promotion_codes` on the no-code path); the two ui_modes (hosted redirect vs on-site PRG flow: `#create` → stash + fingerprint → `GET /checkout` → Stripe custom-UI SDK → `return_url` to `#success`); the `OnsiteCheckout` ENV flag; and a pointer to the spec and ADR 0001. Pull code snippets from the REAL files, not from memory.

- [x] **Step 2: Commit**

```bash
git add docs/developer_guide.md
git commit -m "Rewrite developer guide checkout section for zones and on-site mode"
```

- [x] **Step 3: Rollout checklist** (record in the PR description; these are ops steps, not code)

1. Register **afida.com** and the staging domain for Apple Pay in the Stripe dashboard — **sandbox AND live**. A missed live registration silently hides the wallet button; nothing errors.
2. Confirm `stripe.publishable_key` exists in BOTH sandbox and live credentials.
3. Staging (`ONSITE_CHECKOUT=true`, Stripe sandbox) — full manual checklist from the spec: card; Apple Pay; Link; welcome discount; shopper-typed promo code; invalid promo code; 100%-off code (zero total, `no_payment_required`); samples-only cart (shipping charged, no promo control); off-mainland postcode priced at £25; zone-mismatch guard (price mainland on cart, type a Highlands postcode on the page → pay disabled, warning shown); declined card (4000 0000 0000 0002); `collected_information` present on the resulting order; refresh and back-button on the checkout page; totals match Stripe's charged amounts after a promo code. Watch the browser console for CSP report-only violations and add any missing Stripe hosts.
4. Production: set `ONSITE_CHECKOUT=true`, deploy per `docs/runbooks/deploying.md` (boot by version, verify served HTML). First real order: verify the order record, emails, Telegram notification, and Datafast attribution.
5. Rollback at any point: unset `ONSITE_CHECKOUT`, redeploy. Hosted checkout is untouched by every task above.

---

## Out of scope (per spec — do not build)

Cart editing on the checkout page; shipping-method choice; order notes/custom fields; BNPL; Express Checkout Element; repricing shipping on the page; any change to `#success`, `OrderCreator`, the webhook handler, emails, or events.
