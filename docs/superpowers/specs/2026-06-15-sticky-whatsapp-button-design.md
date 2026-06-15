# Sticky WhatsApp Button — Design

**Date:** 2026-06-15
**Status:** Approved (pending spec review + user review)

## Goal

Add a site-wide floating WhatsApp button to the storefront so visitors can start a
WhatsApp chat with the business from any page. The button is a round, WhatsApp-green
circle pinned to the bottom-right corner, visible on all devices.

## Business details

- **WhatsApp number:** +44 7595 119603 (international, no `+`/spaces/leading-zero: `447595119603`)
- **Prefilled message (generic pages):** `Hi Afida` — a bare, intent-neutral greeting.
  We deliberately do NOT assume the sender's intent (they may have a question, a
  compliment, an order chase, etc.), so the message states nothing beyond the greeting.
- **Prefilled message (product pages):** `Hi Afida, re: <product name> (<SKU>)` — the
  product page enriches the base with the product's `generated_title` and `sku` so the
  lead arrives with context. `re:` references the topic (the page they tapped from, which
  we DO know) without asserting intent. Implemented via
  `content_for(:whatsapp_message_suffix)`, which the partial appends flush to the base.

## Scope

In scope:
- A new shared partial rendered once in the storefront layout.
- A WhatsApp glyph SVG, inlined directly into the partial (the inline markup is the
  single source of truth; no standalone `.svg` file is created).
- Collision avoidance with the existing mobile sticky add-to-cart bar on product pages.

Out of scope:
- The admin layout (`app/views/layouts/admin.html.erb`) — not touched.
- Any analytics/event tracking on click (can be a follow-up).
- A labelled pill or scroll-collapse animation (explicitly not wanted; icon-only chosen).

## Component

### Partial: `app/views/shared/_whatsapp_button.html.erb`

A single self-contained partial. No Stimulus controller is required — it is a plain
anchor link.

Markup:
- `<a>` element with:
  - `href="https://wa.me/447595119603?text=<url-encoded message>"`
    - Uses WhatsApp's official `wa.me` click-to-chat format.
    - The `text` parameter is the URL-encoded prefilled message. Build it with a Rails
      helper (e.g. `CGI.escape` / `url_encode`) rather than hand-encoding, so the
      message text stays readable in the template and encoding is correct.
    - The message is the base string `Hi Afida` by default. If a page sets
      `content_for(:whatsapp_message_suffix)`, the partial appends it flush to the base
      (the suffix carries its own leading punctuation/space) so the message becomes
      context-specific. The product show page sets the suffix to
      `", re: #{@product.generated_title} (#{@product.sku})"`.
  - `target="_blank"` and `rel="noopener"` — opens the WhatsApp app/web client in a new
    context without navigating away from the shop.
  - `aria-label="Chat with us on WhatsApp"` for screen readers.
  - `title="Chat with us on WhatsApp"` for desktop hover.
- Inline white WhatsApp glyph SVG (see asset below).

### WhatsApp glyph SVG

The white WhatsApp glyph is written inline in the partial itself (not saved as a separate
file). Inlining avoids an extra network request and lets the glyph render the white fill
directly. The SVG `fill` is white so it reads against the green circle.

## Appearance

- **Shape/size:** 64px round button (`btn btn-circle`, sized to 64px), matching the
  reference example the user provided.
- **Colour:** WhatsApp brand green `#25D366` background, white glyph.
- **Shadow:** `shadow-lg` for the soft floating look seen in the reference.
- **Hover:** `hover:scale-105 transition-transform` for a subtle affordance.
- **Font weights:** N/A — icon-only, no text. (Project rule: no bold/semibold.)
- **No inline styles** (project rule) — all styling via Tailwind/DaisyUI utility classes.
  The single brand colour `#25D366` is applied via an arbitrary-value utility class
  (e.g. `bg-[#25D366]`), not an inline `style` attribute.

## Positioning & collision handling

- **Base position (all pages):** `fixed bottom-5 right-5 z-40`.
- **Stacking:** `z-40` keeps it above page content but below the toast container and
  modals (`z-50`), so it never covers a dialog.
- **Product page collision:** Product pages render a mobile-only sticky add-to-cart bar
  (`app/views/products/show.html.erb`, the element with
  `data-sticky-atc-target="stickyBar"`) pinned to `bottom-0 inset-x-0 ... md:hidden z-40`.
  It starts hidden (`translate-y-full`) and slides up on scroll. On phones, a button at
  `bottom-5 right-5` would overlap it once it appears.

  **Mechanism:** the product show template sets a flag via `content_for`
  (e.g. `content_for :whatsapp_lift, true`). The WhatsApp partial reads that flag and,
  when present, adds a responsive lift class `max-md:bottom-24` (≈96px, clearing the
  ~64px add-to-cart bar) while keeping `bottom-5` from `md` upward. On all other pages
  the flag is absent and the button stays at `bottom-5`.

  This keeps the collision logic declarative and page-local: only product pages opt into
  the lift, and the WhatsApp partial owns the class decision.

## Layout integration

Render the partial once in `app/views/layouts/application.html.erb`, alongside the other
global UI elements near the end of `<body>` (e.g. after the confirm dialog around line
108, before the GCR widget). It appears on every storefront page that uses the
application layout.

## Accessibility

- `aria-label` describes the action ("Chat with us on WhatsApp").
- The link is keyboard-focusable by default (it is an `<a href>`).
- Colour contrast: white glyph on `#25D366` meets contrast requirements for a graphical
  control.

## Testing

Following the project's TDD practice, write a request/system-level expectation first,
then implement:

1. **Presence on storefront pages:** a request spec asserting the homepage (and another
   storefront page) renders an anchor whose `href` starts with
   `https://wa.me/447595119603` and contains the URL-encoded prefilled message.
2. **Correct attributes:** assert `target="_blank"`, `rel` includes `noopener`, and the
   `aria-label` is present.
3. **Absent on admin:** assert an admin page (using the admin layout) does **not** render
   the WhatsApp button.
4. **Product-page lift:** assert the product show page renders the button with the
   `max-md:bottom-24` lift class (driven by the `content_for` flag), and a non-product
   page renders it without that class.

## Risks / notes

- The number is a UK mobile (`+44 7595 119603`) distinct from the existing landline used
  elsewhere on the site (`0203 302 7719`). That is intended — WhatsApp requires the
  mobile number.
- If the business later wants click analytics, add a data attribute / event hook in a
  follow-up; not included here to keep scope tight.
