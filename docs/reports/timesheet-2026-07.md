---
type: Worklog
description: Measured-elapsed billable hours for July 2026, split into git-derived development sessions and estimated analytics and platform work.
timestamp: 2026-07-31
---

# Timesheet — July 2026 (measured-elapsed basis)

**Developer:** Laurent Curau
**Client:** Afida (bandbeco)
**Project:** afida.com e-commerce platform (Rails)
**Period:** 1–31 July 2026
**Basis:** Measured elapsed time at keyboard. Development hours are computed from the actual time span of each git working session (consecutive commits < 90 min apart) plus a 25-minute lead-in per session. No line-count or output-based uplift is applied.

> This is billed on **time at keyboard, measured from git session spans**, not on how much code changed. That distinction matters because development here is AI-assisted: code is generated and reviewed rather than hand-typed, so output volume (lines/files) is not a proxy for hours; elapsed session time is.

---

## Summary

| | |
|---|---|
| Active working days | 14 |
| Working sessions (git) | 19 |
| Development time (measured elapsed) | 20.00 hours |
| Total billable time | 20.00 hours |
| Rate | £50.00 / hour |
| **Total due** | **£1,000.00** |

---

## Development work (measured from git sessions)

Each day's hours = sum of its working-session spans (first→last commit) + 25 min lead-in per session.

| Date | Work | Hours | Billed |
|------|------|------:|-------:|
| 1 Jul | DataFast goal tracking gated on recorded pageviews, with fail-open cache handling | 0.50 | £25.00 |
| 2 Jul | Admin CRUD for product families (#230); family-only listing grouping (#232); admin dirty-slug form fix (#231); 301 redirects for June category renames | 1.50 | £75.00 |
| 3 Jul | Shop grid pagination and 4-column layout (#233); result count and filter chips (#234); per-unit price lines (#237); search overhaul (relevance ranking, keyboard nav, ARIA, empty states, variant rows) | 2.50 | £125.00 |
| 4 Jul | Worklog auto-append hook for non-code billable time | 0.50 | £25.00 |
| 7 Jul | Auto-301s from persisted category slug history; buying guides and trade metas for bowls and portion pots; category meta fallbacks | 0.75 | £37.50 |
| 8 Jul | DB-driven slug redirect hardening and merge; OKF docs bundle adoption with CI lint; WhatsApp button removal | 1.75 | £87.50 |
| 14 Jul | Reinstated the floating WhatsApp button | 0.50 | £25.00 |
| 15 Jul | Weekly new-business lead monitor (FSA register diffing, digest email, admin view) | 0.50 | £25.00 |
| 22 Jul | Prominent navbar search bar (build, review hardening, merge); robots.txt fix so quick_add noindex works; blog faq_items rendering fix; kamal ssh key pin | 2.00 | £100.00 |
| 24 Jul | Shipping zones: zone model, zone-priced delivery from cart postcode, zone-aware delivery dates on orders, mainland-qualified promises, destination required before checkout | 1.50 | £75.00 |
| 25 Jul | Zone-pricing code-review fixes | 0.50 | £25.00 |
| 27 Jul | Off-mainland delivery policy (£25 flat rate); zone table corrected against DPD's published ranges; postcode field in the cart drawer; unified destination resolution; cart and drawer UX cleanup | 5.25 | £262.50 |
| 28 Jul | On-site checkout (Stripe embedded UI): design spec, ADR, and full first build (env flag, SessionBuilder custom mode, cart fingerprint, zone-lookup endpoint, checkout page wired to Stripe's SDK, CSP, system test); navbar cart dropdown replaced with a cart link; developer guide checkout rewrite | 1.75 | £87.50 |
| 29 Jul | On-site checkout hardening and session-sticky production preview flag (PR #271) | 0.50 | £25.00 |
| | **Subtotal** | **20.00** | **£1,000.00** |

---

## Invoice summary

| Item | Hours | Amount |
|---|---:|---:|
| Development work (measured elapsed) | 20.00 h | £1,000.00 |
| **Billable hours** | **20.00 h** | |
| Rate | £50.00 / hour | |
| Subtotal | | £1,000.00 |
| VAT | | not applied |
| **Total due** | | **£1,000.00** |

---

## Notes on method

- **Time at keyboard, measured not estimated.** Development hours are the actual elapsed span of each git session plus a fixed 25-min lead-in, nothing inferred from how much code changed. This is the right basis when work is AI-assisted, because generated-line volume no longer tracks hours.
- **Absolute floor is 12.16 h** (pure commit-bracket span, zero lead-in). The 25-min lead-in that lifts it to 20.00 h accounts for reading, iterating on, and verifying AI output before the first commit of each session.
- **15 Jul sits on the unmerged `lead-monitor` branch**, so the branch-scan missed it; it is added here under the same session rule (one commit, lead-in only).
- **Non-code analytics, SEO and platform work is not billed this month** at the developer's discretion; July bills development time only.
