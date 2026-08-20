---
type: Plan
description: Product-page buy-box overhaul; one primary CTA, lids attached as compact checkbox cards in the main form, the reverse "fits these containers" view on lid pages, per-unit pricing, a live total, a counting-down free-delivery hint, and a pinned media column.
status: shipped
timestamp: 2026-08-21
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
2. **The attach block as one selection.** Checkbox cards inside `#add-to-cart-form`, carrying the name, an explicit fit cue and the unit rate, with the pack price and a quantity select revealed on tick (see the second pass below; these began as full-width rows showing everything at once). The quantity stays disabled until the card is ticked, so an unticked card contributes nothing to the submission. No card is pre-checked; the curated default sorts first with a "Most popular" cue instead. Ticking seeds the quantity from the product's current quantity once, then never re-syncs.
3. **The reverse view.** `Product#compatible_containers` reads the same join backwards, so lid pages offer the containers they fit with identical card anatomy. Container names link out there (a buyer checking fit may want the dimensions); lid names on container pages do not. Lid pages show four cards plus a "Show all N" disclosure, because a lid can fit a dozen containers and hiding the buyer's own tray would read as "doesn't fit". Container pages keep the hard cap of four.
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

## Shipped

Merged to master and deployed 2026-08-21 (ff `d28c3d42..d1e6f88f`, 19 commits; `kamal deploy --roles=web`, which sidesteps the postgres accessory host that aborts a full `kamal deploy` before the `:latest` retag). Live-verified on served HTML: attach cards and the companions field on container pages, the reverse "fits these containers" block with a correct "Show all 9 compatible containers" disclosure on lid pages, unit price on the price line, spec tiles, and the pinned media column.

## Found during the live check

* The free-delivery hint only recomputed on a selection change, so a buyer arriving with a full cart was told to reach a threshold they had already passed until they touched something. Fixed by handing the controller the total the page opens on, with a regression test at the HTTP seam.
* `sort_order` ranks lids within one container, so it says nothing about how containers rank against each other, and the join's `default_scope` was deciding the lid page's list arbitrarily. The reverse association reorders by position then name, which matters because the tail sits behind a disclosure and rows must not shuffle between loads.

## Second pass: layout and contrast (2026-08-21)

Measured on the live page after the first pass shipped to the branch. The attach block was 728px, taller than the whole rest of the buy box (~320px), which put Add to Cart at y=1522 on an 828px screen. Datafa.st (last 30 days, stable over 12 months) also reframed the priority: mobile is 61% of visitors but converts at roughly 40% of desktop's per-visitor rate, and product pages are 55% of traffic.

The scroll-depth problem turned out to be desktop-only: the sticky add-to-cart bar reveals whenever the main CTA is off-screen, which on mobile means from scroll 0, so a phone buyer always has a button on screen. That killed an earlier idea of moving the CTA above the attach block, which would have traded the Total-last guarantee for a fix mobile did not need.

What changed:

* **Mobile: floating chat button overlap.** The WhatsApp button is fixed to the bottom-right and paints above the page; a row's full-width quantity select ran underneath it, so at several scroll depths a tap meant for the lid quantity opened a chat. Row controls now reserve that corner on narrow screens (two overlapping controls before, none after).
* **Mobile: centred rows.** The rows inherited the buy column's centre alignment, so each name, cue and price rendered as centred fragments. Explicit left alignment.
* **Compact cards.** Two across, carrying only what a buyer chooses on (name, fit cue, unit rate). Pack price and pack count ride along hidden and appear on tick. Block 728px to 328px, CTA 1522px to 1162px, and 736px to 453px on mobile.
* **Pinned media column** on wide screens only (`lg:sticky` plus `lg:items-start` on the flex parent, since stretched children cannot scroll within). The image box is 620px against an 806px viewport, so it pins cleanly. Phones stack, and stay unpinned.
* **Checkbox contrast.** The box was drawn in brand mint at 1.45:1 against the card, under the 3:1 WCAG asks of a control, and it was the only mark that a card was selectable. Neutral border at 6.57:1 unchecked, mint as the checked fill.
* **Sample button** from outlined brand-mint to ghost with a neutral ring, so it stops reading as a second primary beside the real CTA.
* **Quantity stepper** rebuilt as one bordered shell. The site-wide `.btn { border-radius: 9999px }` defeated DaisyUI's `join`, leaving pill buttons either side of a square field with doubled, overlapping borders. Extracted to a partial, since the tiered and flat-priced buy boxes each carried a copy.

## Out of scope

Size/variant picker (own design explorations and URL/SEO implications), photography, quick-add card styling (belongs to the shop-grid workstream), the WhatsApp floating button (the apparent overlap was a full-page screenshot artifact), and catalog data fixes such as the truncated-looking `CNT` SKU.
