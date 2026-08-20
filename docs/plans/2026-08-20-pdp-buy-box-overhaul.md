---
type: Plan
description: Product-page buy-box overhaul; one primary CTA, lids attached as checkbox rows in the main form, the reverse "fits these containers" view on lid pages, per-unit pricing, a live total and a counting-down free-delivery hint.
status: shipped
timestamp: 2026-08-20
---

# Product Page Buy Box Overhaul

Issue [#285](https://github.com/bandbeco/afida-b2c/issues/285). Builds on the [Compatible Lids Overhaul](/plans/2026-08-18-compatible-lids-overhaul.md), which made the curated join table the sole source of truth for what fits what. That work fixed the data; this fixes what the product page does with it.

## What was wrong

Judged against two reference pages: the PP Lid Stagione 170x120x18mm (lid side) and the Kraft Food Tray PE-Lined 650ml (container side).

* **The attach block was three mini buy boxes.** Each compatible lid carried its own quantity dropdown and its own "Add to Cart" button, stacked above the real one, so four identical primary buttons competed for the same click. Each lid button fired a bespoke `fetch` to the cart endpoint.
* **The Total lied.** It sat directly above the primary CTA, reflected only the product's own quantity, and ignored lids already added, so the last number a buyer read before committing was wrong.
* **Lid pages answered neither of a lid buyer's questions.** No compatibility information at all, and Related Products offered four rival lids: substitutes to defect to, on a page where the buyer wanted to confirm fit and buy the matching tray.
* **No per-unit price in the buy box.** It led the grid cards already, but on the page itself a GBP 93.62 lid pack beside a GBP 46.38 tray read as a pricing error rather than as unit economics.
* **Exit ramps mid-purchase.** "Can't find what you're looking for?" and the free-sample block sat between the quantity stepper and Add to Cart.
* **Static free-delivery hint** ("over GBP 100") when the cart state was already known.
* **Recyclable listed as a certification**, beside FSC and EN 13432.

## What shipped

1. **Companion items on the cart endpoint.** `POST /cart/cart_items` takes an optional `companions` array beside the primary `cart_item`, and applies the same per-item rules (sample replacement, quantity merge on same product and price) to each inside one transaction. The mapping governs what the page renders, never what the cart accepts: any active SKU is allowed since prices resolve server-side, and unknown, inactive or zero-quantity companions are skipped rather than failing the add. The endpoint is therefore reusable for cross-sells with no mapping behind them.
2. **The attach block as one selection.** Checkbox rows inside `#add-to-cart-form`: unit price leading, pack price secondary, an explicit fit cue, and a quantity select that stays disabled until the row is ticked. No row is pre-checked; the curated default sorts first with a "Most popular" cue instead. Ticking seeds the row's quantity from the product's current quantity once, then never re-syncs.
3. **The reverse view.** `Product#compatible_containers` reads the same join backwards, so lid pages offer the containers they fit with identical row anatomy. Container names link out there (a buyer checking fit may want the dimensions); lid names on container pages do not. Lid pages show four rows plus a "Show all N" disclosure, because a lid can fit a dozen containers and hiding the buyer's own tray would read as "doesn't fit". Container pages keep the hard cap of four.
4. **Live total.** The attach block announces its selection; the quantity and tier controllers fold it into the running total, with "Includes anything ticked above" under the label.
5. **Per-unit price on the price line**, through one shared helper (pence with one decimal below a pound). Tiered products quote the tier they open on and the tier controller keeps it in step, never a "from" range.
6. **Free delivery counts down.** Threshold and cart subtotal come from the server, the client subtracts the on-page selection, and the hint flips to a qualified state at zero. Mainland-qualified, since the product page does not know the destination.
7. **Buy column resequenced**: title, price, SKU, description, quantity, attach block, delivery promise, total, one primary Add to Cart. The contact and sample routes move below it.
8. **Recyclability moved to Materials.** A small allow-list in the specification presenter; unrecognised tokens stay certifications so a real one is never quietly demoted. The stored column is unchanged.

The bespoke per-lid `fetch` controller is deleted. The mobile sticky bar submits the main form by reference, so it inherits companions unchanged.

## Decisions worth remembering

* **No pre-checked lids.** Opt-out add-ons at pack prices burn trust with repeat trade buyers, and the total must open at the advertised price.
* **Soft quantity sync, not hard.** Seeding at tick time matches the dominant intent (pack counts mirror each other) without overriding a buyer who then sets their own number.
* **The mapping is a rendering concern.** Keeping validation out of the cart endpoint is what makes it generic.
* **No feature flag.** The companions param is backwards-compatible and the main add-to-cart stays a plain form submit, so the worst failure mode is "attach doesn't work", not "nobody can buy".

## Testing

HTTP seam only: what a GET renders and what a POST does to the cart. Block-level integration tests per concern (attach block, unit price, live total wiring, buy-box order, free-delivery data), controller tests for the companion contract, model tests for the reverse association and the certification split. The live-total arithmetic and checkbox interactivity are not system-tested; the repo keeps system tests sparse and the behaviour was verified live instead.

## Found during the live check

* The free-delivery hint only recomputed on a selection change, so a buyer arriving with a full cart was told to reach a threshold they had already passed until they touched something. Fixed by handing the controller the total the page opens on, with a regression test at the HTTP seam.
* `sort_order` ranks lids within one container, so it says nothing about how containers rank against each other, and the join's `default_scope` was deciding the lid page's list arbitrarily. The reverse association reorders by position then name, which matters because the tail sits behind a disclosure and rows must not shuffle between loads.

## Out of scope

Size/variant picker (own design explorations and URL/SEO implications), photography, quick-add card styling (belongs to the shop-grid workstream), the WhatsApp floating button (the apparent overlap was a full-page screenshot artifact), and catalog data fixes such as the truncated-looking `CNT` SKU.
