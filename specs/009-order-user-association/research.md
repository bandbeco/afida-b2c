# Research: Order User Association

**Feature**: 009-order-user-association
**Date**: 2025-11-26

## Executive Summary

Codebase analysis reveals that most of the order-user association functionality already exists. The primary gap is a **security vulnerability** in the order show action that allows any authenticated user to view any order.

## Research Findings

### 1. Order-User Database Association

**Status**: ✅ Already Implemented

**Evidence**:
- `app/models/order.rb:2` - `belongs_to :user, optional: true`
- `app/models/user.rb:10` - `has_many :orders, dependent: :destroy`
- Database column `user_id` exists on orders table

**Decision**: No database changes required.
**Rationale**: The association is properly configured as optional to support guest checkout.

---

### 2. Order Association at Checkout

**Status**: ✅ Already Implemented

**Evidence**:
- `app/controllers/checkouts_controller.rb:52-55` - Passes `client_reference_id: Current.user.id` to Stripe for logged-in users
- `app/controllers/checkouts_controller.rb:150` - Retrieves user from `stripe_session.client_reference_id`
- `app/controllers/checkouts_controller.rb:153-154` - Creates order with `user: user`

**Decision**: No changes required to checkout flow.
**Rationale**: The existing implementation correctly associates orders with logged-in users while supporting guest checkout.

---

### 3. Order History (Index)

**Status**: ✅ Already Implemented

**Evidence**:
- `app/controllers/orders_controller.rb:10` - `@orders = Current.user.orders.recent.includes(:order_items, :products)`
- `app/views/orders/index.html.erb:78-89` - Empty state handling exists

**Decision**: No changes required.
**Rationale**: Index already scopes to current user and handles empty state.

---

### 4. Order Show Authorization

**Status**: ❌ SECURITY VULNERABILITY

**Evidence**:
- `app/controllers/orders_controller.rb:16` - `@order = Order.includes(order_items: :product_variant).find(params[:id])`
- No authorization check - fetches ANY order by ID
- Any authenticated user can view any order by guessing/incrementing IDs

**Decision**: Fix by scoping order lookup to current user's orders.
**Rationale**: This is a data exposure vulnerability that violates FR-003 (restrict order viewing to owner).

**Alternatives Considered**:

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Scope to `Current.user.orders.find(id)` | Simple, uses Rails conventions | Raises RecordNotFound for unauthorized access | ✅ Selected |
| Manual check after fetch | Can provide custom error message | More code, potential timing attack | Rejected |
| Pundit/CanCanCan authorization gem | Standard pattern | Overkill for single use case | Rejected |

---

### 5. Guest Order Access Policy

**Status**: ⚠️ Policy Decision Required

**Question**: How should guest orders (orders with no user_id) be accessed after checkout?

**Current Behavior**:
- Guest can view order on confirmation page immediately after checkout
- No way to access order later (no account to log into)

**Decision**: Maintain current behavior (Option A).
**Rationale**:
1. Spec states "Guest checkout functionality should continue to work" - this doesn't require adding new features
2. Adding order lookup by email/order number is out of scope
3. Simple implementation aligns with feature's security focus

---

### 6. Rails Authorization Best Practices

**Research**: Rails controller authorization patterns

**Best Practice for Simple Cases**:
```ruby
# Scope lookup to association - raises RecordNotFound if not found
def set_order
  @order = Current.user.orders.find(params[:id])
end
```

**Handling Not Found**:
- Rails default: Renders 404 page (acceptable)
- Custom: Rescue and redirect with flash message (better UX)

**Decision**: Use scoped lookup with custom RecordNotFound handling.
**Rationale**: Provides both security (can't access others' orders) and good UX (helpful error message instead of 404).

---

### 7. Test Coverage Analysis

**Current Test Files**:
- `test/controllers/orders_controller_test.rb` - Exists but needs authorization tests
- No dedicated integration or system tests for order authorization

**Required Test Scenarios**:
1. User can view own order (happy path)
2. User cannot view another user's order (security)
3. User cannot view guest order (security)
4. Unauthenticated user redirected to login

**Decision**: Add controller tests for authorization; add system test for user journey.
**Rationale**: Constitution requires test-first development and coverage for security-critical flows.

## Implementation Recommendations

1. **Modify `set_order` method** to scope to current user's orders
2. **Add `rescue_from ActiveRecord::RecordNotFound`** with redirect to orders index
3. **Write failing tests first** per TDD requirements
4. **Keep changes minimal** - only fix the authorization gap

## Open Questions

None - all clarifications resolved through codebase analysis.
