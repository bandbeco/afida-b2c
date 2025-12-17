# User Address Storage

## Overview

Allow logged-in users to save multiple delivery addresses so they can checkout faster without re-entering address details each order. Saved addresses prefill Stripe Checkout while still allowing users to enter new addresses when needed.

## Goals

- Logged-in users can save multiple delivery addresses
- One address marked as default (auto-selected at checkout)
- Saved addresses prefill Stripe Checkout
- Users can still enter a new address at checkout
- New addresses can be saved after checkout completes
- Full CRUD management in account settings

## Non-Goals

- Billing addresses (Stripe handles this via payment method)
- Guest user address storage
- Address validation/autocomplete (future enhancement)

## Data Model

### New table: `addresses`

| Column | Type | Constraints |
|--------|------|-------------|
| id | bigint | Primary key |
| user_id | bigint | Foreign key, not null, indexed |
| nickname | string | Not null (e.g., "Home", "Office") |
| recipient_name | string | Not null |
| company_name | string | Nullable |
| line1 | string | Not null |
| line2 | string | Nullable |
| city | string | Not null |
| postcode | string | Not null |
| phone | string | Nullable |
| country | string | Not null, default "GB" |
| default | boolean | Not null, default false |
| created_at | datetime | |
| updated_at | datetime | |

### Model

```ruby
class Address < ApplicationRecord
  belongs_to :user

  validates :nickname, :recipient_name, :line1, :city, :postcode, presence: true
  validates :country, presence: true

  before_save :ensure_single_default

  scope :default_first, -> { order(default: :desc, created_at: :asc) }

  def formatted_address
    [
      recipient_name,
      company_name,
      line1,
      line2,
      "#{city}, #{postcode}"
    ].compact_blank.join(", ")
  end

  private

  def ensure_single_default
    if default? && default_changed?
      user.addresses.where.not(id: id).update_all(default: false)
    end
  end
end

class User < ApplicationRecord
  has_many :addresses, dependent: :destroy

  def default_address
    addresses.find_by(default: true) || addresses.first
  end

  def has_saved_addresses?
    addresses.exists?
  end
end
```

## User Interface

### 1. Account Settings Page

**Route:** `GET /account/addresses`

**Layout:**
```
┌─────────────────────────────────────────────────────────────────┐
│  Account  ›  Delivery Addresses                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Office                                    ┌─────────┐  │   │
│  │  ════════                                  │ DEFAULT │  │   │
│  │  John Smith                                └─────────┘  │   │
│  │  Acme Catering Ltd                                      │   │
│  │  123 High Street, Unit 4                                │   │
│  │  London, SW1A 1AA                                       │   │
│  │  07700 900123                                           │   │
│  │                                                         │   │
│  │  Edit  •  Delete                                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Warehouse                                              │   │
│  │  ══════════                                             │   │
│  │  Reception                                              │   │
│  │  Acme Catering Ltd                                      │   │
│  │  45 Industrial Estate                                   │   │
│  │  Manchester, M1 2AB                                     │   │
│  │                                                         │   │
│  │  Edit  •  Delete  •  Set as default                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│       + Add new address                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Add/Edit form fields:**
- Nickname (required) - e.g., "Office", "Home"
- Recipient name (required)
- Company name (optional)
- Address line 1 (required)
- Address line 2 (optional)
- City (required)
- Postcode (required)
- Phone (optional)
- "Set as default" checkbox

**Deletion behaviour:**
- Confirmation required before delete
- If deleting default address and others exist, oldest remaining becomes default

### 2. Pre-Checkout Modal

When logged-in user with saved addresses clicks "Checkout":

```
┌─────────────────────────────────────────────────────────────────┐
│  Select delivery address                                    ✕   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ◉  Office (Default)                                    │   │
│  │     John Smith, Acme Catering Ltd                       │   │
│  │     123 High Street, Unit 4, London, SW1A 1AA           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ○  Warehouse                                           │   │
│  │     Reception, Acme Catering Ltd                        │   │
│  │     45 Industrial Estate, Manchester, M1 2AB            │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ○  Enter a different address                           │   │
│  │     You'll enter your address at checkout               │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│                               ┌────────────────────────────┐   │
│                               │   Continue to checkout →   │   │
│                               └────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Behaviour:**
- Default address pre-selected
- Selecting saved address → Stripe checkout with address prefilled
- Selecting "Enter a different address" → Stripe checkout with empty form
- Modal doesn't appear if user has no saved addresses
- Guest users skip modal entirely

### 3. Post-Checkout Save Prompt

On order confirmation page, for logged-in users who used a new address:

```
┌─────────────────────────────────────────────────────────────────┐
│  ✓ Order confirmed!                                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  💡 Save this address for faster checkout?              │   │
│  │                                                         │   │
│  │  John Smith, 99 New Street, Birmingham, B1 1AA          │   │
│  │                                                         │   │
│  │  Nickname: ┌─────────────────┐                          │   │
│  │            │ e.g. "Office"   │                          │   │
│  │            └─────────────────┘                          │   │
│  │                                                         │   │
│  │  ┌──────────────┐  ┌──────────────┐                     │   │
│  │  │  No thanks   │  │     Save     │                     │   │
│  │  └──────────────┘  └──────────────┘                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Order #AF-12345 ...                                            │
└─────────────────────────────────────────────────────────────────┘
```

**Logic:**
- Only shown to logged-in users
- Only shown if order's delivery address doesn't match any saved addresses (fuzzy match on line1 + postcode)
- User only needs to provide a nickname
- "No thanks" dismisses the prompt
- "Save" creates address with `default: false` (unless it's their first)

## Checkout Flow Changes

### CheckoutsController#create

```ruby
def create
  # ... existing code ...

  session_params = {
    # ... existing params ...
  }

  # Prefill address if user selected a saved one
  if params[:address_id].present? && Current.user
    address = Current.user.addresses.find_by(id: params[:address_id])
    if address
      session_params[:customer_details] = {
        address: {
          line1: address.line1,
          line2: [address.company_name, address.line2].compact.join(", ").presence,
          city: address.city,
          postal_code: address.postcode,
          country: address.country
        },
        name: address.recipient_name,
        phone: address.phone
      }
    end
  end

  session = Stripe::Checkout::Session.create(session_params)
  # ...
end
```

**Notes:**
- Company name concatenated into line2 (Stripe doesn't have separate field)
- Stripe still shows address form (prefilled) so user can confirm/edit
- Phone passed if available

### Cart Form Changes

- Hidden `address_id` field added to checkout form
- Stimulus controller sets value when user selects from modal
- Empty value if "Enter different address" selected

## Routes

```ruby
namespace :account do
  resources :addresses, except: [:show] do
    member do
      patch :set_default
    end
    collection do
      post :create_from_order
    end
  end
end
```

## Components Summary

| Component | Description |
|-----------|-------------|
| `addresses` table | New table for storing user addresses |
| `Address` model | Validations, default handling, user association |
| `Account::AddressesController` | CRUD + set_default + create_from_order |
| `/account/addresses` view | Address list and add/edit forms |
| Checkout address modal | Address selection before Stripe redirect |
| `checkout-address` Stimulus controller | Modal interaction, form submission |
| Confirmation page save prompt | Post-checkout address save UI |
| `CheckoutsController` changes | Accept address_id, prefill Stripe |

## Testing Strategy

### Model tests
- Address validations (required fields)
- Single default per user enforcement (callback)
- User#default_address method
- User#has_saved_addresses? method
- Address#formatted_address helper

### Controller tests
- CRUD operations for addresses
- Authorization (users can only access own addresses)
- set_default action
- create_from_order action
- Checkout with/without address_id parameter

### System tests
- Add/edit/delete addresses in account settings
- Set default address
- Checkout flow with saved address selection
- Pre-checkout modal appears/doesn't appear appropriately
- Post-checkout address save prompt
- Address prefill verification in Stripe
