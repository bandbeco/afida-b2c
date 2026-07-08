---
type: Worklog
description: Measured-elapsed billable hours for June 2026, split into git-derived development sessions and estimated analytics and platform work.
timestamp: 2026-07-04
---

# Timesheet — June 2026 (measured-elapsed basis)

**Developer:** Laurent Curau
**Client:** Afida (bandbeco)
**Project:** afida.com e-commerce platform (Rails)
**Period:** 1–30 June 2026
**Basis:** Measured elapsed time at keyboard. Development hours are computed from the actual time span of each git working session (consecutive commits < 90 min apart) plus a 25-minute lead-in per session. No line-count or output-based uplift is applied.

> This is billed on **time at keyboard, measured from git session spans**, not on how much code changed. That distinction matters because development here is AI-assisted: code is generated and reviewed rather than hand-typed, so output volume (lines/files) is not a proxy for hours; elapsed session time is.

---

## Summary

| | |
|---|---|
| Active working days | 18 |
| Working sessions (git) | 32 |
| Development time (measured elapsed) | 35.0 hours |
| Analytics & platform work (developer-estimated) | 8.0 hours |
| Total billable time | 43.0 hours |
| Rate | £50.00 / hour |
| **Total due** | **£2,150.00** |

---

## Development work (measured from git sessions)

Each day's hours = sum of its working-session spans (first→last commit) + 25 min lead-in per session. Day figures are rounded to the quarter-hour; the billed subtotal is the exact session total.

| Date | Work | Hours | Billed |
|------|------|------:|-------:|
| Mon 1 Jun | Delivery-promise consistency; confirmation-email copy | 1.0 | £50.00 |
| Tue 2–3 Jun | Sample-quantity "1 unit" display on order pages; supplier SKU exposed on admin product edit form | 1.25 | £62.50 |
| Mon 8 Jun | SKU-generation design specs (family codes + product recipe) | 0.5 | £25.00 |
| Wed 10 Jun | Product cost field + admin form; order date/time formatting | 0.5 | £25.00 |
| Thu 11 Jun | Internal ops order-confirmation email with supplier SKUs; branded 404 page; Ruby 4.0.5 + ruby-vips | 2.5 | £125.00 |
| Sun 15 Jun | Sitewide floating WhatsApp button (spec, build, mobile layout, admin guard) | 1.0 | £50.00 |
| Mon 16 Jun | Klaviyo integration + abandoned-cart email; PII-leak fix; WhatsApp finalising; docs cleanup | 5.0 | £250.00 |
| Tue 17 Jun | Klaviyo abandoned-cart for logged-in users; empty-cart suppression | 1.75 | £87.50 |
| Thu 18 Jun | First-order discount 5%→10% + coupon mapping; blog "Shop our range" CTA | 3.5 | £175.00 |
| Fri 19 Jun | Datafast visitor-id tracking fix; admin inline Category/Family edit + perf; brandable specs | 2.0 | £100.00 |
| Mon 22 Jun | Datafast API-key 401 fix; admin product form; tiered per-unit pricing; config-sourced shipping | 2.5 | £125.00 |
| Tue 23 Jun | OrderTotals module extraction; 6oz cup size; Back/Forward nav fix | 4.0 | £200.00 |
| Wed 24 Jun | VAT on shipping; checkout hardening (zero-total, pagination, samples); live Stripe tests | 2.75 | £137.50 |
| Thu 25 Jun | Checkout error handling; webhook retry-suppression; slug redirects; cart-preview shipping | 2.0 | £100.00 |
| Fri 26 Jun | VAT-on-shipping ship; totals unified across emails/pages/admin/PDF; promo-code recording; 404 redirects | 3.25 | £162.50 |
| Mon 29 Jun | Reviewed + merged 7 dependency updates | 0.5 | £25.00 |
| Tue 30 Jun | GA4 begin_checkout events; 3 dependency merges | 1.0 | £50.00 |
| | **Subtotal** | **35.0** | **£1,750.00** |

---

## Analytics & platform work (not version-controlled)

Work done outside the codebase in third-party tools, so it leaves no commit trail. Hours are estimated by the developer as time at keyboard; the deliverables are described below.

| Period | Work | Deliverable | Hours | Billed |
|--------|------|-------------|------:|-------:|
| ~19–22 Jun | Diagnosed and root-caused the Datafast conversion-tracking failure across dashboard, prod logs and the goal API; restored purchase-conversion reporting that had been under-counting real orders. | Working conversion tracking | 4.0 | £200.00 |
| ~16–17 Jun | Built the Klaviyo email flows by hand in the Klaviyo UI (abandoned-cart flow, templates, segments). | Live abandoned-cart flow | 4.0 | £200.00 |
| | | **Subtotal** | **8.0** | **£400.00** |

---

## Invoice summary

| Item | Hours | Amount |
|---|---:|---:|
| Development work (measured elapsed) | 35.0 h | £1,750.00 |
| Analytics & platform work (estimated) | 8.0 h | £400.00 |
| **Billable hours** | **43.0 h** | |
| Rate | £50.00 / hour | |
| Subtotal | | £2,150.00 |
| VAT | | not applied |
| **Total due** | | **£2,150.00** |

---

## Notes on method

- **Time at keyboard, measured not estimated.** Development hours are the actual elapsed span of each git session plus a fixed 25-min lead-in, nothing inferred from how much code changed. This is the right basis when work is AI-assisted, because generated-line volume no longer tracks hours.
- **Absolute floor is ~21.6 h** (pure commit-bracket span, zero lead-in, after removing the Telegram work). The 25-min lead-in that lifts it to 35.0 h accounts for reading, iterating on, and verifying AI output before the first commit of each session.
- **June 11 excludes Telegram order notifications.** That feature (~0.5 h of the day's work) was built unprompted and is not billed; the day reflects only the ops-email, 404-page and Ruby-upgrade work.
- **Analytics/platform hours are separate and developer-estimated** — dashboard work, not affected by the AI-coding point.
