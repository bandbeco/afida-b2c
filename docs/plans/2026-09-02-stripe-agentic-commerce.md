---
type: Plan
description: Sell Afida's stock catalogue through AI chat agents via Stripe Agentic Commerce Suite in four phases, reusing the Google Merchant feed data, the existing UK VAT tax rate, the postcode shipping zones and the checkout.session.completed webhook.
status: active
timestamp: 2026-09-03
---

# Stripe Agentic Commerce Suite (ACS) Integration

Stripe ACS lets a seller list products with AI chat agents (ChatGPT and others Stripe connects) and accept in-agent checkout with one integration. The seller pushes CSV catalog feeds to Stripe, Stripe syndicates them to agents, and completed purchases arrive as ordinary `checkout.session.completed` events. GB is a supported country.

This plan covers what Afida has to build, in what order, and which existing pieces carry over. It is scoped to plain stock products. Branded (customizable template) products, samples and volume-tier pricing stay website-only in this iteration; see [Decisions](#decisions).

Sources: Stripe's seller guide (`docs.stripe.com/agentic-commerce/for-sellers`), the catalog feed spec (`.../agentic-commerce/product-feed`), and the manage guide (`.../agentic-commerce/for-sellers/manage`), all read on 2026-09-02.

## What already fits

| Need | Existing piece | Notes |
| --- | --- | --- |
| Stripe client | `stripe` gem 19.5, API version `2025-12-15.clover` | v2 `client.v2.commerce.product_catalog.imports` is available on this gem line. |
| Catalog data | `GoogleMerchantFeedGenerator` | Already computes optimised title and description, image URL, product URL, brand, GTIN or `identifier_exists`, MPN, category path, Google taxonomy id, item group id, colour, material, size. ACS wants the same fields under nearly the same names. |
| Order intake | `Webhooks::StripeController#handle_checkout_completed` | Signature verification, idempotency on `stripe_event_id`, retryable vs permanent error split, shipping address extraction, `Checkout::SessionAmounts`. |
| VAT | `Checkout::StripeTaxRateProvider` | Afida charges a single 20% UK VAT tax rate exclusive of price. ACS's checkout customization hook accepts a v1 tax rate id, so Stripe Tax is not required. |
| Shipping | `Shipping`, `ShippingZone` | £6.99 standard, free over £100 for free-shipping zones, higher cost for non-mainland zones derived from postcode. The feed carries the flat rule; the hook carries the zone rule. |
| Recurring jobs | Solid Queue `config/recurring.yml` | Add the feed push jobs alongside the pending-order jobs. |

## What does not carry over

- **Cart-less orders.** Both order paths (success redirect and webhook fallback) rebuild order items from a `Cart` found via session metadata. Agent sessions are created by Stripe, have no cart and no Afida metadata. Order items have to be built from the session's line items instead.
- **Pack and tier pricing.** `Checkout::SessionBuilder` folds pack count into `unit_amount` and picks a `pricing_tiers` price by quantity. ACS has one `price` per feed row and charges `price × quantity`. Agents will buy N packs at the single-pack price.
- **Inventory.** `Product#in_stock?` is `active?`; `stock_quantity` is not consulted. ACS supports `inventory_not_tracked=true`, which matches reality. There is nothing to send in an inventory feed until stock is tracked.
- **Branded products.** Need artwork and a design review step. Exclude from the feed, or send with `disable_checkout=true` so agents can still recommend them and hand off to the website.
- **Game and welcome promo codes.** Stripe promotion codes applied through `SessionBuilder` are invisible to agents. The promotion feed can carry a code, but the £100-threshold STACK codes are per-customer and not worth mirroring in this iteration.

## Phase 1: Account, sandbox and product feed

Goal: Afida's stock catalogue is visible in the Stripe sandbox feed view and passes validation with zero row errors.

Progress 2026-09-03: code items 1 to 5 are built on branch `agentic-commerce-plan` (`AgenticCommerce::ProductFeed`, `ProductFeedAttributes` shared with the Google feed, `AgenticCommerce::FeedUploader`, `AgenticCommerce::PushProductFeedJob` at 03:00 daily, the `agentic_commerce_imports` table, and `bin/rails agentic_commerce:push_product_feed` / `agentic_commerce:preview_product_feed`). First upload done 2026-09-03 from the production container: 656 rows, `succeeded` with no row errors, in live mode (the task uses the credentials key; there is no sandbox key override yet). Do not request an agent connection until Phase 2 lands: without the hooks and the cart-less order path, an agent checkout would take payment and the webhook would fail to build the order. `delete=true` rows are deferred to Phase 3 as planned; `custom_variant_option_*` was dropped in favour of `size` carrying the pack count.

**Dashboard (Afida leadership, with dev support)**

1. Agentic commerce page in the Stripe Dashboard: onboard as a seller, complete the Stripe profile with terms of service, privacy policy and returns policy URLs from afida.com.
2. Leave capture mode at automatic; refunds continue through the existing Dashboard workflow.
3. If a restricted key is used for feed pushes, grant it Product Catalog Import write.

**Code (dev retainer)**

1. `AgenticCommerce::ProductFeed` service in `app/services/agentic_commerce/`. Input: a relation of products. Output: CSV string. Extract the shared title, description, image and identifier logic out of `GoogleMerchantFeedGenerator` into a small `ProductFeedAttributes` value object that both generators consume, so the two feeds cannot drift.
2. Column mapping for each stock product (`Product.active.where(product_type: "standard")`, excluding sample products):

   | ACS column | Source |
   | --- | --- |
   | `id` | `product.sku` (same id as the Google feed, so the Stripe `external_reference` on the price maps straight back) |
   | `title`, `description` | shared optimised title and description; description plain text, max 5000 chars |
   | `link` | `product_url(product)` |
   | `image_link`, `additional_image_link` | product photo, then lifestyle photo |
   | `brand` | `product.brand` or `Afida` |
   | `gtin` / `mpn` | `product.gtin` when present, else `mpn = sku` |
   | `condition` | `new` |
   | `google_product_category` | existing mapping |
   | `product_category` | `Parent > Child` category path |
   | `item_group_id`, `item_group_title`, `color`, `material`, `size` | existing family logic; `size` from volume or `Pack of N` |
   | `custom_variant_option_name_1` / `value_1` | `Pack size` / `pac_size` when the family varies by pack size |
   | `availability` | `in_stock` when active, `out_of_stock` otherwise |
   | `inventory_not_tracked` | `true` |
   | `price` | `pricing_tiers.first["price"]` or `product.price`, as `12.34 GBP` |
   | `tax_behavior` | `exclusive` |
   | `shipping` | `GB:ALL:Standard:1-2:6.99 GBP` from `Shipping::STANDARD_COST` |
   | `free_shipping_threshold` | `GB:ALL:Standard:100.00 GBP` from `Shipping::FREE_SHIPPING_THRESHOLD` |
   | `shipping_cost_basis` | `per_order` |
   | `custom_label_1`, `custom_label_3` | best-seller flag, category slug (as Google feed) |
   | `disable_checkout` | blank for stock products |
   | `delete` | `true` for products deactivated since the last push (see Phase 3) |

   `stripe_product_tax_code` is deliberately blank: Phase 2 supplies the tax rate through the hook instead of Stripe Tax. Confirm in the sandbox that a feed without a tax code plus the custom-tax-rates hook produces a taxed checkout; if Stripe insists on a code, use `txcd_99999999` (general tangible goods) as the placeholder, with the hook still authoritative.

3. `AgenticCommerce::FeedUploader` wrapping the two-step import: create a `ProductCatalogImport` with `feed_type` and `mode`, then `PUT` the CSV to the presigned URL within its 5-minute window. Returns the import id. Uses `Stripe::StripeClient` with the existing secret key. Mode is always `upsert`; `replace` is never used from code. The gem (19.5, pinned to `2026-07-29.dahlia`) ships `client.v2.commerce.product_catalog.imports`, but the app forces `Stripe.api_version = "2025-12-15.clover"` and Stripe's API examples send `Stripe-Version: 2026-08-26.preview` for this endpoint. Pass `stripe_version` per call in the uploader rather than moving the global pin, and confirm in the sandbox which version the endpoint accepts.
4. `AgenticCommerce::PushProductFeedJob`, scheduled daily at 03:00 in `config/recurring.yml`, plus a `bin/rails agentic_commerce:push_product_feed` task for manual runs and the first sandbox upload.
5. Record each push in an `agentic_commerce_imports` table: `stripe_import_id`, `feed_type`, `mode`, `row_count`, `status`, `error_file_summary`, timestamps. This is what Phase 3 monitoring and the deletion diff read from.

**Tests (write first)**

- `test/services/agentic_commerce/product_feed_test.rb`: header row matches the column list; a standard product renders every required column; a branded product is excluded; a sample product is excluded; price format `12.34 GBP`; GTIN present drops MPN requirement; description is plain text and truncated at 5000; shipping string built from `Shipping` constants so an env override flows through.
- `test/services/agentic_commerce/feed_uploader_test.rb`: stubs the v2 create and the presigned PUT, asserts the import row is written with `awaiting_upload` then `processing`.
- `test/services/google_merchant_feed_generator_test.rb`: still green after the attribute extraction.

**Exit criteria**

- Sandbox import reaches `succeeded` with the full stock catalogue.
- Dashboard feed view shows the product count matching `Product.active.standard.count`.
- Google Merchant feed output unchanged (diff the XML before and after the refactor).

## Phase 2: Hooks and cart-less order creation

Goal: a test purchase from the Dashboard's feed view creates a paid `Order` with correct items, VAT, shipping and addresses, and fires the usual Telegram and Klaviyo notifications.

**Checkout customization hook** (`POST /webhooks/stripe/agentic_checkout`)

Stripe calls this before quoting a checkout, with line items and the shipping address. Enable both Custom tax rates and Custom shipping options in Agentic commerce settings. The endpoint:

1. Verifies the signature with the Agentic Commerce Extension event destination secret (a new credential, `stripe.agentic_hook_secret`).
2. Derives the zone from `shipping_details.address.postal_code` via `ShippingZone`, the same call `SessionBuilder#zone` makes. Returns one `shipping_options` entry with `Shipping.cost_for_zone(zone)`, `tax_behavior: exclusive`, the zone's transit label as `display_name`, and amount `0` when `Shipping.free_shipping?` holds for the order's `amount_subtotal`. Rejects non-GB countries by returning no shipping options (confirm in sandbox that this declines the checkout; otherwise use the approval hook below).
3. Returns `line_items[].tax_rates = [{ rate: StripeTaxRateProvider.uk_vat_rate_id }]` for every line item.
4. Responds within 4 seconds and is idempotent: it is a pure function of the request.

**Order approval hook** is optional. Enable it only if the sandbox shows that non-GB addresses cannot be blocked from the customization hook. It would decline when the country is not in `Shipping::ALLOWED_COUNTRIES` and otherwise approve.

**Product price and availability hook** is deferred. Without stock tracking it would only echo the feed.

**Cart-less order creation**

1. In `Webhooks::StripeController#handle_checkout_completed`, after the existing "order already exists" guard, branch on `full_session.metadata["cart_id"]`. Absent cart id means an agent session. Retrieve with `expand: ["line_items.data.price.product", "collected_information", "payment_intent.latest_charge", "total_details.breakdown"]`.
2. New `Checkout::AgentOrderCreator` (parallel to `OrderCreator`) that builds `OrderItem`s from line items: `product = Product.find_by!(sku: line_item.price.external_reference)`, `quantity = line_item.quantity`, `price = line_item.price.unit_amount / 100`, `pac_size = product.pac_size`, `line_total = line_item.amount_subtotal / 100`. Shipping is recognised by the shipping-rate line rather than the `shipping_line` metadata flag, so `Checkout::SessionAmounts` needs a second constructor or a small adapter that reads `total_details.amount_shipping` for agent sessions.
3. Order attributes: `email` from `customer_details`, no user or organisation (match by email later if a customer record exists, but do not auto-link), `status: paid`, `source: "agent"` (new string column on `orders`, default `"web"`), `agent_name` from `payment_intent.agent_details` when the preview field is present, else from the Dashboard tag.
4. An unknown SKU raises `PermanentlyInvalidSessionError` and alerts Sentry; the payment has been taken, so ops need to see it immediately rather than have Stripe retry forever.
5. Downstream side effects (Telegram notification, Klaviyo event, Margot research) must run for agent orders exactly as for web orders. Audit that they key off `Order` creation and not off the redirect controller.

**Tests (write first)**

- `test/controllers/webhooks/agentic_checkout_controller_test.rb`: signature required; mainland postcode returns £6.99 exclusive; subtotal ≥ £100 mainland returns £0; Highlands postcode returns the zone cost; every line item gets the UK VAT rate id; response time is not asserted but the handler makes no external calls beyond the cached tax rate lookup.
- `test/services/checkout/agent_order_creator_test.rb`: builds items from `external_reference`; totals match `amount_total`; unknown SKU raises permanent error; no cart touched.
- `test/controllers/webhooks/stripe_controller_test.rb`: a session without `cart_id` routes to the agent creator; a session with `cart_id` is unchanged.
- Order notification tests: an agent-sourced order triggers Telegram and Klaviyo.

**Exit criteria**

- Sandbox test purchase (Agentic commerce page, View feed, hover a product, Test) produces an `Order` whose subtotal, VAT, shipping and total equal the Stripe session's, tagged `source: agent`.
- Repeating the webhook delivery does not duplicate the order.
- A test purchase to a non-GB address is declined.

## Phase 3: Freshness, deletions and monitoring

Goal: the Stripe catalogue never advertises a price or product that afida.com no longer sells.

1. **Pricing feed on change.** `after_commit` on `Product` when `price`, `pricing_tiers` or `active` change enqueues `AgenticCommerce::PushPriceFeedJob` (debounced to one run per 5 minutes via a Solid Queue concurrency key). The job sends only changed SKUs with `id, price`. Deactivations go in the product feed with `delete=true` rather than the price feed.
2. **Daily product feed** remains the full upsert; it includes `delete=true` rows for every SKU present in the previous successful push but no longer eligible. The eligible-SKU set of each push is stored on the import record for that diff.
3. **Import webhooks.** Subscribe a v2 event destination to `v2.commerce.product_catalog.imports.succeeded`, `succeeded_with_errors` and `failed`. Handler updates the import record; on `succeeded_with_errors` it downloads the error CSV inside the 5-minute window, stores the first 50 `stripe_error_message` rows on the record and posts a Telegram alert. `failed` alerts Sentry.
4. **Ops view.** Admin page listing imports with status and error summary. No new UI framework: reuse the admin table partials.

**Tests (write first)**

- Price change enqueues one job for two rapid edits; the CSV has only the changed SKU.
- Deactivating a product yields a `delete=true` row on the next product feed and nothing on the price feed.
- Import webhook transitions and error-file capture, with the download stubbed.

## Phase 4: Go live and promotions

1. Repeat the Phase 1 upload against live mode; confirm the Dashboard count.
2. Request connection to the first agent from the Agentic commerce page; review its terms with Afida leadership before clicking.
3. Watch the Transactions page filter by agent for the first week and reconcile against `Order.where(source: "agent")`.
4. Once orders flow, consider a promotion feed row for the welcome discount (`application_type: promotion_code`, `minimum_order_amount: 100.00 GBP`) so agents can surface it. Keep the STACK game codes website-only.

## Decisions

- **Stock products only, single-pack price.** Agents charge `pricing_tiers.first` × quantity. Customers who want tier pricing are handed to afida.com by the product link. Revisit if agent orders regularly exceed tier-2 quantities; the fix is either an approval-hook repricing (not supported today, the hook only approves or declines) or per-tier feed rows, which distorts the catalogue.
- **Branded products excluded** rather than `disable_checkout=true` for the first push, to keep the validation surface small. Flip to discovery-only in Phase 4 if agents' recommendations are worth the redirect traffic.
- **Custom tax rate hook instead of Stripe Tax.** Keeps one VAT source of truth and avoids a Stripe Tax registration. If the sandbox shows the hook cannot override tax without Stripe Tax enabled, enable Stripe Tax for GB only and set `stripe_product_tax_code` on every row.
- **`orders.source` column** rather than inferring from missing metadata after the fact, so reporting and the reorder-schedule code can exclude agent orders explicitly.
- **No inventory feed** until `stock_quantity` is maintained. `inventory_not_tracked=true` is honest and avoids a 15-minute job that sends nothing new.

## Open questions

- Resolved 2026-09-03: the v2 imports endpoint accepts `2026-08-26.preview`, and a feed with no `stripe_product_tax_code` ingests with zero row errors. Whether checkout then taxes correctly through the customization hook alone is still a Phase 2 sandbox check.
- Does returning zero shipping options from the customization hook decline the checkout, or does Stripe fall back to the feed's shipping rule? Determines whether the approval hook is needed.
- Is `payment_intent.agent_details` (private preview) available on Afida's account? If not, agent attribution comes only from the Dashboard filter.
- Are agent orders eligible for the reorder-schedule and abandoned-cart flows? Default here is no; confirm with Afida.

## Related

- [Advertising Optimization](/plans/2025-11-06-advertising-optimization.md): the Google Merchant feed this plan refactors.
- [Google Ads campaign structure](/proposals/implementation/03-google-ads-campaign-structure.md): feed quality guidance that applies unchanged to agent syndication.
- [Hormozi Trilogy Implementation](/plans/2026-08-17-hormozi-trilogy-implementation.md): the promotions in Phase 4 draw on the Grand Slam Offer welcome discount.
