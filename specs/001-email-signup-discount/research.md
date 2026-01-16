# Research: Email Signup Discount

**Feature**: 001-email-signup-discount
**Date**: 2026-01-16

## Research Summary

This feature had extensive requirements gathering during brainstorming. All major decisions were resolved before planning. This document captures the decisions and rationale for reference.

---

## Decision 1: Placement of Signup Form

**Decision**: Cart page only (not popup, not checkout)

**Rationale**:
- Cart visitors are warm leads already considering purchase
- B2B buyers (target audience) find popups intrusive
- Checkout uses Stripe hosted page, making inline elements awkward
- Cart is a natural pause point where value proposition resonates

**Alternatives Considered**:
- Exit-intent popup: Rejected as too aggressive for B2B
- Footer form: Could be added later for general newsletter signups
- Checkout inline: Not feasible with Stripe Checkout redirect model

---

## Decision 2: Discount Delivery Method

**Decision**: Instant apply (discount shown immediately, stored in session)

**Rationale**:
- Highest conversion—no friction between signup and discount
- Session-based approach works with both guest and logged-in users
- No email deliverability concerns

**Alternatives Considered**:
- Email delivery: Adds friction, risks abandonment
- Account creation required: Too much friction for first-time buyers

---

## Decision 3: Fraud Prevention Strategy

**Decision**: Email-based eligibility check (no email normalization)

**Rationale**:
- Check `email_subscriptions` table for previous claims
- Check `orders` table for previous purchases
- Case-insensitive comparison sufficient for most abuse
- Email normalization (plus-addressing, Gmail dots) deferred—B2B customers unlikely to abuse for 5% savings

**Alternatives Considered**:
- Plus-address stripping: Added complexity, marginal benefit
- Full Gmail normalization: Provider-specific, maintenance burden
- Cookie/browser tracking: Easily bypassed, adds privacy concerns

---

## Decision 4: Eligibility Scope

**Decision**: First-time customers only (no previous orders)

**Rationale**:
- Clear "welcome offer" positioning
- Avoids "why didn't I get this?" from existing customers
- Separate loyalty programs can reward returning customers

**Alternatives Considered**:
- First signup only (even returning customers): Confusing positioning
- Newsletter-only (anyone): Dilutes new customer incentive

---

## Decision 5: Stripe Integration Approach

**Decision**: Single reusable coupon (`WELCOME5`), eligibility controlled by application

**Rationale**:
- Simple to manage—one coupon to create
- Application validates eligibility before applying
- Stripe handles discount math at checkout

**Alternatives Considered**:
- Unique codes per email: More complex, harder to manage
- Stripe promotion codes: Less control over eligibility logic

---

## Decision 6: Session vs. Database for Discount State

**Decision**: Rails session stores `discount_code`, cleared after successful order

**Rationale**:
- First-party cookies not blocked by browsers
- Session persists through Stripe redirect flow
- No additional database state needed for discount tracking
- Simple cleanup on order completion

**Alternatives Considered**:
- Database flag on cart: Adds complexity, cart already transient
- Database flag on user: Doesn't work for guest checkout

---

## Technical Research: Stripe Coupon API

**Finding**: Stripe Checkout Session accepts `discounts` array with coupon IDs.

```ruby
session_params[:discounts] = [{ coupon: "WELCOME5" }]
```

**Setup Required**: Create coupon via Stripe Dashboard or API:
- ID: `WELCOME5`
- Percent off: 5%
- Duration: once
- No redemption limit (app controls eligibility)

---

## Technical Research: Turbo Streams for Form Updates

**Finding**: Turbo Streams allow replacing form without full page reload.

Pattern:
```ruby
render turbo_stream: turbo_stream.replace(
  "discount-signup",
  partial: "email_subscriptions/success"
)
```

**Benefit**: Seamless UX—form transitions to success state instantly.

---

## Open Items (Deferred)

None—all decisions resolved during brainstorming phase.
