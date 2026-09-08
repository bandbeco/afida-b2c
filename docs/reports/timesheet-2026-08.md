---
type: Worklog
description: Measured-elapsed billable hours for August 2026, development only, derived from git working sessions.
timestamp: 2026-08-28
---

# Timesheet — August 2026 (measured-elapsed basis)

**Developer:** Laurent Curau
**Client:** Afida (bandbeco)
**Project:** afida.com e-commerce platform (Rails)
**Period:** 1–28 August 2026
**Basis:** Measured elapsed time at keyboard. Development hours are computed from the actual time span of each git working session (consecutive commits < 90 min apart) plus a 25-minute lead-in per session. No line-count or output-based uplift is applied.

> This is billed on **time at keyboard, measured from git session spans**, not on how much code changed. That distinction matters because development here is AI-assisted: code is generated and reviewed rather than hand-typed, so output volume (lines/files) is not a proxy for hours; elapsed session time is.

---

## Summary

| | |
|---|---|
| Active working days | 12 |
| Working sessions (git) | 16 |
| Development time (measured elapsed) | 34.50 hours |
| Total billable time | 34.50 hours |
| Rate | £50.00 / hour |
| **Total due** | **£1,725.00** |

---

## Development work (measured from git sessions)

Each day's hours = sum of its working-session spans (first→last commit) + 25 min lead-in per session.

| Date | Work | Hours | Billed |
|------|------|------:|-------:|
| 6 Aug | On-site checkout (Stripe custom UI) branch merged behind the ONSITE_CHECKOUT flag | 0.50 | £25.00 |
| 7 Aug | Welcome-coupon hardening: repeat redemption of the one-time coupon stopped, eligibility consolidated onto one rule, two review defects fixed; rake task backfilling orders.discount_code from Stripe; July SEO measurement and docs recorded | 1.75 | £87.50 |
| 9–10 Aug | Growth-strategy proposals from the Hormozi frameworks: Grand Slam Offer companion, money-model offer sequence, and $100M Leads proposals | 1.00 | £50.00 |
| 17 Aug | Seventeen dependency PRs reviewed and merged; overdue reorder schedules advanced when their pending order expires; billing address collected and displayed alongside shipping; Hormozi trilogy implementation plan with phased checklist | 3.75 | £187.50 |
| 18 Aug | Compatible-lids overhaul: curated join table as sole source, propose/review/apply mapping pipeline, admin panel opened to all non-lid products, cart "Don't forget lids" reminder, production prune. Live shipping reprice on the on-site checkout (client-synced addresses, superseded-session guard, cart-side pricing teardown); Billing Address Element mounted; on-site checkout enabled in production. /vegware consolidated into /collections/vegware (301); every Google taxonomy id in the merchant feed corrected | 9.25 | £462.50 |
| 19 Aug | Email-bombing incident response: attack attributed via kamal-proxy logs, verification email suppressed then bounded, Cloudflare ranges trusted so remote_ip is the visitor; deploy keys listed for both machines; SEO gap coverage plan, range-gaps proposal, and keyword cluster map; compatible-lids review fixes | 1.75 | £87.50 |
| 20 Aug | Buy-box overhaul: compatible lids folded into the buy form as ticked companions with a live total, free-delivery countdown, per-unit rate on the price line. Category taxonomy seeded and corrected against production; verification emails re-enabled behind the shipped throttles; edge-challenge and origin-firewall layers recorded; db accessory pointed at its private address | 7.00 | £350.00 |
| 21 Aug | Buy-box and cart second pass: free-delivery progress bar and countdown on cart surfaces, flash redesigned as a toast, quantity stepper rebuilt as one control, specifications as fact tiles, media column pinned beside the buy box; refused Stripe coupons dropped with an explanation instead of blocking the sale; empty-cart 500 fixed; welcome email icons hosted for Gmail; £100 welcome-discount minimum stated; returns pointed at the Coventry address; four review defects fixed | 3.00 | £150.00 |
| 25 Aug | AI crawler traffic tracked server-side via DataFast (PR #288), with review fixes | 2.25 | £112.50 |
| 27 Aug | Deploy tooling: Kamal deploys with the SSH key read from 1Password, bin/load-deploy-key extracted, agent-check and invocation fixes (PR #289). Margot customer-research integration: order notifications tag Margot, prospect research triggered via her OpenClaw gateway webhook, mention replaced with a share button | 3.00 | £150.00 |
| 28 Aug | Margot integration hardening: research moved to her main agent with a persistent session, tailnet hostname pinned to her Tailscale IP, afida agent targeted, research prompt given the manual flow's depth cues | 1.25 | £62.50 |
| | **Subtotal** | **34.50** | **£1,725.00** |

---

## Invoice summary

| Item | Hours | Amount |
|---|---:|---:|
| Development work (measured elapsed) | 34.50 h | £1,725.00 |
| **Billable hours** | **34.50 h** | |
| Rate | £50.00 / hour | |
| Subtotal | | £1,725.00 |
| VAT | | not applied |
| **Total due** | | **£1,725.00** |

---

## Notes on method

- **Time at keyboard, measured not estimated.** Development hours are the actual elapsed span of each git session plus a fixed 25-min lead-in, nothing inferred from how much code changed. This is the right basis when work is AI-assisted, because generated-line volume no longer tracks hours.
- **Absolute floor is 27.94 h** (pure commit-bracket span, zero lead-in). The 25-min lead-in that lifts it to 34.50 h accounts for reading, iterating on, and verifying AI output before the first commit of each session.
- **The 9 Aug session crossed midnight into 10 Aug**; it is one session, shown as one row, so the table has 11 rows over 12 active calendar days.
- **No non-code analytics, SEO or platform work is billed this month**; August bills development time only.
