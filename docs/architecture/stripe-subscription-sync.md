# Stripe Subscription Sync: Known Limitations

## Current Implementation

The subscription management feature (Phase 8 of sign-up-accounts) allows users to view, pause, resume, and cancel subscriptions through our UI. When users take these actions:

1. We call the Stripe API directly
2. On success, we update our local database

This ensures **outbound sync** - changes made in our app are reflected in Stripe.

## Known Limitation: No Inbound Sync

Our database can become out of sync with Stripe when changes originate from outside our application:

| Event | Stripe Status | Our DB Status | In Sync? |
|-------|---------------|---------------|----------|
| User cancels via our app | cancelled | cancelled | ✓ |
| User cancels via Stripe billing portal | cancelled | active | ✗ |
| Subscription expires naturally | cancelled | active | ✗ |
| Payment fails → Stripe auto-cancels | cancelled | active | ✗ |
| Admin changes in Stripe Dashboard | varies | stale | ✗ |
| Subscription renews successfully | active | active | ✓ |

## Impact

- Users may see incorrect subscription status in their account
- Paused subscriptions that resume in Stripe will show as paused in our UI
- Cancelled subscriptions may still appear active

## Future Work: Webhook Integration

To maintain sync, implement Stripe webhook handlers:

```ruby
# app/controllers/webhooks/stripe_controller.rb
class Webhooks::StripeController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']

    event = Stripe::Webhook.construct_event(
      payload, sig_header, Rails.application.credentials.stripe[:webhook_secret]
    )

    case event.type
    when 'customer.subscription.updated'
      handle_subscription_updated(event.data.object)
    when 'customer.subscription.deleted'
      handle_subscription_deleted(event.data.object)
    when 'customer.subscription.paused'
      handle_subscription_paused(event.data.object)
    when 'customer.subscription.resumed'
      handle_subscription_resumed(event.data.object)
    end

    head :ok
  rescue Stripe::SignatureVerificationError
    head :bad_request
  end

  private

  def handle_subscription_updated(stripe_sub)
    subscription = Subscription.find_by(stripe_subscription_id: stripe_sub.id)
    return unless subscription

    subscription.update!(
      status: map_stripe_status(stripe_sub.status),
      current_period_end: Time.at(stripe_sub.current_period_end)
    )
  end

  def handle_subscription_deleted(stripe_sub)
    subscription = Subscription.find_by(stripe_subscription_id: stripe_sub.id)
    subscription&.update!(status: :cancelled, cancelled_at: Time.current)
  end

  def map_stripe_status(stripe_status)
    case stripe_status
    when 'active' then :active
    when 'paused' then :paused
    when 'canceled', 'cancelled' then :cancelled
    else :active
    end
  end
end
```

### Required Setup

1. Add route: `post '/webhooks/stripe', to: 'webhooks/stripe#create'`
2. Configure webhook in Stripe Dashboard → Developers → Webhooks
3. Add webhook secret to credentials: `stripe.webhook_secret`
4. Subscribe to events:
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `customer.subscription.paused`
   - `customer.subscription.resumed`

### Testing Webhooks Locally

Use Stripe CLI to forward webhooks to localhost:

```bash
stripe listen --forward-to localhost:3000/webhooks/stripe
```

## Alternative: Sync on Read

A lighter-weight alternative is to fetch current status from Stripe when displaying subscription details:

```ruby
def show
  @subscription = current_user.subscriptions.find(params[:id])
  @stripe_subscription = Stripe::Subscription.retrieve(@subscription.stripe_subscription_id)

  # Opportunistically sync if out of date
  if status_changed?(@subscription, @stripe_subscription)
    @subscription.update!(status: map_stripe_status(@stripe_subscription.status))
  end
end
```

**Trade-offs:**
- Pro: No webhook infrastructure needed
- Con: Adds latency to every page load
- Con: Won't update status until user views the page
- Con: Additional API calls to Stripe

## Recommendation

Implement webhook handlers as the primary sync mechanism. This provides:
- Real-time sync without user interaction
- No additional latency on page loads
- Foundation for other Stripe integrations (payments, invoices)
