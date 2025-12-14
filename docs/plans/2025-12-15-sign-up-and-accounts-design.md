# Sign-Up Page & User Accounts Design

## Overview

Redesign the sign-up experience and account features to drive repeat purchases from B2B customers. Loyal business clients already order regularly through the website - accounts should make reordering faster and easier.

## Business Context

- **Primary goal:** Reduce friction for repeat B2B purchases
- **Customer behavior:** Loyal business clients order regularly, currently re-entering details each time
- **Core value proposition:** "Reorder in seconds. Your order history, saved and ready."

## Feature Split: Guest vs Logged-In

| Feature | Guests | Logged-in |
|---------|--------|-----------|
| Browse products | Yes | Yes |
| Add to cart | Yes | Yes |
| Checkout | Yes | Yes |
| View single order (via email link) | Yes | Yes |
| Order history (all past orders) | No | Yes |
| Reorder previous order | No | Yes |
| Subscriptions | No | Yes |
| Saved addresses | No | Yes |
| Request samples | Yes | Yes |

**Principle:** Never block purchasing. Gate features that require persistent identity.

---

## Section 1: Sign-Up Page Redesign

**Goal:** Convert the functional-only form into a page that communicates value.

### Layout

```
┌─────────────────────────────────────────────┐
│                                             │
│         Create your Afida account           │
│    Reorder in seconds. Your order history,  │
│              saved and ready.               │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │  Email                                │  │
│  │  [________________________]           │  │
│  │                                       │  │
│  │  Password                             │  │
│  │  [________________________]           │  │
│  │                                       │  │
│  │  Confirm Password                     │  │
│  │  [________________________]           │  │
│  │                                       │  │
│  │  [      Create Account      ]         │  │
│  │                                       │  │
│  │  Already have an account? Log in      │  │
│  └───────────────────────────────────────┘  │
│                                             │
│   ✓ View your complete order history        │
│   ✓ Reorder previous orders in one click    │
│   ✓ Set up recurring orders (coming soon)   │
│                                             │
└─────────────────────────────────────────────┘
```

### Changes from Current

- Add tagline below heading: "Reorder in seconds. Your order history, saved and ready."
- Add 3 benefit bullets below the form
- Mark subscriptions as "coming soon" to set expectations
- Keep form fields identical (email, password, confirm password)

---

## Section 2: Post-Checkout Account Conversion

**Goal:** Convert guest buyers into account holders at the moment of highest intent.

### Location

Order confirmation page (`/orders/:id/confirmation`) - only shown for guest orders.

### UI

```
┌─────────────────────────────────────────────┐
│  ✓ Order confirmed! #1234                   │
│                                             │
│  [Existing order details...]                │
│                                             │
├─────────────────────────────────────────────┤
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │                                       │  │
│  │   Save this order to your account     │  │
│  │   Reorder in one click next time.     │  │
│  │                                       │  │
│  │   Password                            │  │
│  │   [________________________]          │  │
│  │                                       │  │
│  │   Confirm Password                    │  │
│  │   [________________________]          │  │
│  │                                       │  │
│  │   [   Create Account   ]              │  │
│  │                                       │  │
│  │   We'll use: customer@email.com       │  │
│  │                                       │  │
│  └───────────────────────────────────────┘  │
│                                             │
└─────────────────────────────────────────────┘
```

### Behavior

- Email pre-filled from Stripe checkout session (read-only)
- User only enters password + confirmation
- On success: create User, attach Order to new User, log them in
- If email already has account: show "This email already has an account. Log in to link this order."

---

## Section 3: Reorder Previous Order

**Goal:** Let logged-in users copy a past order into their cart with one click.

### UI - Order History Page

```
┌─────────────────────────────────────────────┐
│  Your Orders                                │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │ Order #1234 · 12 Dec 2025 · £156.00   │  │
│  │ 3 items: Single Wall Cups, Napkins... │  │
│  │                                       │  │
│  │ [View]           [Reorder]            │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

### UI - Individual Order Page

```
┌─────────────────────────────────────────────┐
│  Order #1234                    [Reorder]   │
│  Placed 12 December 2025                    │
│                                             │
│  [Order items list...]                      │
└─────────────────────────────────────────────┘
```

### Reorder Behavior

1. User clicks "Reorder"
2. Add all items from that order to current cart
3. If cart has existing items: add to cart (don't replace)
4. If product/variant unavailable: skip it, show notice
5. Redirect to cart with success message: "3 items added to your cart"

---

## Section 4: Subscriptions (V1 - Fixed Schedule)

**Goal:** Let logged-in users set up recurring orders on a fixed schedule.

### Scope for V1

- Fixed frequencies: Weekly, Every 2 Weeks, Monthly
- No pause/skip/modify (cancel and recreate instead)
- Email notification when order is placed automatically

### Entry Point - Cart Page

```
┌─────────────────────────────────────────────┐
│  Your Cart                                  │
│                                             │
│  [Cart items list...]                       │
│                                             │
│  ──────────────────────────────────────     │
│                                             │
│  ☐ Make this a recurring order              │
│     Deliver: [ Every 2 weeks ▼ ]            │
│                                             │
│  [Proceed to Checkout]                      │
└─────────────────────────────────────────────┘
```

### Account Area - Manage Subscriptions

```
┌─────────────────────────────────────────────┐
│  Your Subscriptions                         │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │ Subscription #1 · Every 2 weeks       │  │
│  │ Next order: 29 Dec 2025               │  │
│  │                                       │  │
│  │ 3 items: Single Wall Cups (x2),       │  │
│  │          Napkins (x1)                 │  │
│  │                                       │  │
│  │ [View Items]         [Cancel]         │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

### Technical Approach

- Use Stripe Subscriptions with `mode: 'subscription'` in Checkout Session
- Store subscription reference in new `Subscription` model
- Webhook receives `invoice.paid` → creates Order automatically
- Email customer when auto-order is placed

### V1 Limitations (Explicit)

- Can't modify items - must cancel and create new subscription
- Can't pause - must cancel and recreate later
- Can't change frequency - must cancel and recreate

---

## Section 5: Account Dashboard & Navigation

**Goal:** Give logged-in users a clear home for their account features.

### Header Navigation (Logged In)

```
┌─────────────────────────────────────────────────────────────┐
│  [Logo]   Shop   About   Contact       [Account ▼]  [Cart]  │
└─────────────────────────────────────────────────────────────┘
                                              │
                                              ▼
                                    ┌──────────────────┐
                                    │ Order History    │
                                    │ Subscriptions    │
                                    │ Account Settings │
                                    │ ──────────────── │
                                    │ Log Out          │
                                    └──────────────────┘
```

### Account Settings Page (`/account`)

```
┌─────────────────────────────────────────────┐
│  Account Settings                           │
│                                             │
│  Email                                      │
│  customer@business.com         [Change]     │
│                                             │
│  Password                                   │
│  ••••••••••                    [Change]     │
│                                             │
└─────────────────────────────────────────────┘
```

### V1 Scope

- Email/password management only
- No saved addresses page (addresses come from Stripe Checkout)
- No profile fields (collect at checkout as needed)

### Future Additions (Not V1)

- Saved addresses management
- Company/business profile
- Team members (organization features already exist in User model)

---

## Implementation Phases

### Phase 1: Sign-Up Page & Post-Checkout Conversion

- Update sign-up page with value proposition messaging
- Add post-checkout account creation prompt on confirmation page
- Create endpoint to convert guest order to new account

### Phase 2: Order History & Reorder

- Improve order history page UI with reorder buttons
- Add reorder button to individual order page
- Build "add order items to cart" logic with unavailable item handling

### Phase 3: Account Navigation

- Add account dropdown to header for logged-in users
- Create account settings page (email/password change)
- Update existing pages to use new navigation

### Phase 4: Subscriptions (V1)

- Add subscription checkbox/frequency selector to cart
- Integrate Stripe Subscriptions for recurring billing
- Create Subscription model and management page
- Set up webhooks for auto-order creation
- Email notifications for subscription orders

### Rationale

- Phases 1-2 deliver the core value proposition (reordering) fast
- Phase 3 is polish/navigation
- Phase 4 (subscriptions) is most complex - do it last when foundation is solid

---

## Design Decisions Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Registration fields | Email + password only | Lower friction; collect business details at checkout |
| Post-checkout conversion | Password-only form | Email already captured from Stripe |
| Reorder behavior | Add to existing cart | Less destructive; user can remove unwanted items |
| Subscription V1 | Fixed schedule only | Simpler ops; learn what flexibility customers actually need |
| Sign-up prompts | Header + post-checkout | Header is standard; post-checkout is highest intent moment |
