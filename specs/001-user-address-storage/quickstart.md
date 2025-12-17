# Quickstart: User Address Storage

**Feature**: 001-user-address-storage
**Estimated Time**: 2-3 days

## Overview

This feature adds saved delivery addresses for logged-in users, enabling faster checkout through Stripe Checkout prefill.

## Prerequisites

- Rails development environment running (`bin/dev`)
- PostgreSQL database active
- Test suite passing (`rails test`)

## Implementation Order

### Phase 1: Data Layer (Day 1 Morning)

1. **Create Migration**
   ```bash
   rails generate migration CreateAddresses
   ```

2. **Run Migration**
   ```bash
   rails db:migrate
   ```

3. **Create Address Model**
   - File: `app/models/address.rb`
   - Validations, callbacks, scopes

4. **Extend User Model**
   - Add `has_many :addresses`
   - Add `default_address` and `has_saved_addresses?` methods

5. **Write Model Tests**
   - File: `test/models/address_test.rb`

### Phase 2: Controller & Routes (Day 1 Afternoon)

1. **Add Routes**
   ```ruby
   # config/routes.rb
   namespace :account do
     resources :addresses, except: [:show] do
       member { patch :set_default }
       collection { post :create_from_order }
     end
   end
   ```

2. **Create Controller**
   - File: `app/controllers/account/addresses_controller.rb`
   - CRUD actions + `set_default` + `create_from_order`

3. **Write Controller Tests**
   - File: `test/controllers/account/addresses_controller_test.rb`

### Phase 3: Views (Day 2 Morning)

1. **Address List Page**
   - `app/views/account/addresses/index.html.erb`
   - `app/views/account/addresses/_address.html.erb`

2. **Address Form**
   - `app/views/account/addresses/_form.html.erb`
   - `app/views/account/addresses/new.html.erb`
   - `app/views/account/addresses/edit.html.erb`

3. **Add Link to Account Navigation**
   - Update account menu to include "Addresses" link

### Phase 4: Checkout Integration (Day 2 Afternoon)

1. **Pre-Checkout Modal**
   - `app/views/carts/_checkout_address_modal.html.erb`
   - Stimulus controller: `checkout_address_controller.js`

2. **Modify CheckoutsController**
   - Accept `address_id` parameter
   - Prefill Stripe Checkout with selected address

3. **Integration Tests**
   - File: `test/integration/checkout_address_prefill_test.rb`

### Phase 5: Post-Checkout Save (Day 3 Morning)

1. **Save Prompt on Confirmation**
   - `app/views/orders/_save_address_prompt.html.erb`
   - Logic to detect new addresses

2. **System Tests**
   - File: `test/system/address_management_test.rb`

## Quick Verification Steps

### After Phase 1

```bash
rails test test/models/address_test.rb
rails console
# > u = User.first
# > u.addresses.create!(nickname: "Test", recipient_name: "John", line1: "123 St", city: "London", postcode: "SW1A 1AA")
# > u.default_address
```

### After Phase 2

```bash
rails test test/controllers/account/addresses_controller_test.rb
# Visit http://localhost:3000/account/addresses (logged in)
```

### After Phase 4

```bash
rails test test/integration/checkout_address_prefill_test.rb
# Add item to cart, click checkout, verify modal appears
# Select address, verify Stripe prefill
```

### After Phase 5

```bash
rails test
rails test:system
```

## Key Files Created

| Category | Files |
|----------|-------|
| Model | `app/models/address.rb` |
| Migration | `db/migrate/YYYYMMDDHHMMSS_create_addresses.rb` |
| Controller | `app/controllers/account/addresses_controller.rb` |
| Views | `app/views/account/addresses/*.erb`, `_checkout_address_modal.html.erb`, `_save_address_prompt.html.erb` |
| Stimulus | `app/frontend/javascript/controllers/checkout_address_controller.js` |
| Tests | `test/models/address_test.rb`, `test/controllers/account/addresses_controller_test.rb`, `test/integration/checkout_address_prefill_test.rb`, `test/system/address_management_test.rb` |

## Common Issues

### Issue: Modal not appearing

**Check**: Stimulus controller registered in `application.js`

```javascript
const lazyControllers = {
  // ...
  "checkout-address": () => import("../javascript/controllers/checkout_address_controller")
}
```

### Issue: Address not prefilling in Stripe

**Check**: `customer_details` parameter format in CheckoutsController

```ruby
session_params[:customer_details] = {
  address: { line1: ..., city: ..., postal_code: ..., country: ... },
  name: ...,
  phone: ...
}
```

### Issue: Default not updating

**Check**: `ensure_single_default` callback running

```ruby
before_save :ensure_single_default

def ensure_single_default
  if default? && default_changed?
    user.addresses.where.not(id: id).update_all(default: false)
  end
end
```

## Success Criteria Verification

| Criterion | How to Verify |
|-----------|---------------|
| SC-001: Add address in <60s | Time manual test |
| SC-002: 50% faster checkout | Compare with/without prefill |
| SC-004: Modal in <500ms | Browser DevTools Network tab |
| SC-005: Correct prefill | Stripe Checkout visual verification |
| SC-006: No unauthorized access | Controller tests for scoping |
