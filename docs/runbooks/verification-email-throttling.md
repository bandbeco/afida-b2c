---
type: Runbook
description: How verification-email sending is bounded, what trips each limit, and what to do when legitimate signups are being refused.
status: active
timestamp: 2026-08-19
---

# Verification Email Throttling

Added 2026-08-19 after ~10 "Verify your email address" emails arrived at `hello@afida.com` in 47 minutes. They are visible there because `RegistrationMailer` carries `default bcc: "hello@afida.com"`, so that inbox is a live feed of every account registration — not, as first assumed, of the newsletter form, which sends no mail at all.

## Why this matters more than it looks

Every one of these messages leaves with `from: hello@afida.com`. If the form is being used to mail addresses the sender chose, the reputational damage lands on our sending domain, not on the attacker. A burned sending domain takes weeks to rebuild and silently degrades order confirmations along the way.

## The three layers

| Layer | Where | Limit | Stops |
| --- | --- | --- | --- |
| Honeypot | `RegistrationsController::HONEYPOT_FIELD` | n/a | Bots that fill every input |
| Per-user budget | `VerificationEmailThrottle::PER_USER_HOURLY_LIMIT` | 3/hour | Resend-endpoint looping |
| Global ceiling | `VerificationEmailThrottle::GLOBAL_HOURLY_LIMIT` | 50/hour | Distributed signup runs |

The honeypot is a hidden `secondary_reference` field. Anything arriving in it did not render the page, so the submission is dropped and answered with the **same** notice a real signup gets — a bot told which field caught it simply stops filling that field. The name is deliberately meaningless: anything resembling company/website/url gets pattern-matched by password managers and browser autofill, several of which ignore `autocomplete="off"`, and a customer whose manager filled it would be dropped as silently as a bot.

The per-user budget closes `EmailAddressVerificationsController#create`. Before it, one authenticated session could loop that endpoint without bound, each iteration sending mail. It is keyed on user id, not IP, so rotating addresses does not reset it.

The global ceiling is the blast-radius cap. A distributed run presents a different user every request, so the per-user budget never trips and this is the only bound on total volume. It deliberately prefers suppressing genuine verification mail during a burst over letting the domain be used to bomb third parties.

Note what it does **not** do: it refuses the *send*, not the signup. The account is still created and the visitor still signed in, and since nothing in the app gates on `email_address_verified`, that account works normally. They are told the email could not be sent (`VERIFICATION_UNAVAILABLE_NOTICE`) rather than being pointed at an inbox nothing was sent to.

## When legitimate verification mail is being suppressed

Symptom: users report never receiving a verification email, and the log carries `[verification] send suppressed by throttle`. Their accounts still work; only the email is missing.

1. Read the current spend: `VerificationEmailThrottle.global_spent`.
2. If it is at the ceiling, decide whether this is an attack or genuine growth. Attack evidence: many distinct users, each with 1–2 sends, from scattered IPs. Genuine growth: sustained legitimate signup volume that has simply outgrown 50/hour.
3. Genuine growth is a config change — raise `GLOBAL_HOURLY_LIMIT`. Do not raise it to clear an attack; that is the limit doing its job.
4. `[registrations] honeypot tripped` lines carry the IP and user-agent of caught bots and are the cheapest read on whether an attack is live.

Budgets live in `Rails.cache` (solid_cache in production) on a one-hour expiry, so they self-clear. There is no manual reset; if you must clear one early, delete the `verification_email:*` keys.

## Attribution

`Session` records `ip_address` and `user_agent` at creation, and registration always opens a session, so every signup leaves a fingerprint:

```
kamal app exec -p --reuse --quiet 'bin/rails runner "
  User.where(created_at: 24.hours.ago..).order(:created_at).each { |u|
    s = u.sessions.order(:created_at).first
    puts [u.created_at, u.email_address, u.email_address_verified, s&.ip_address, s&.user_agent].join(%q{ | }) }
"'
```

See [Deploying to Production](/runbooks/deploying.md) for kamal access. Note that `config/deploy.yml` pins `~/.ssh/id_ed25519` with `keys_only: true`, which is machine-specific: it only resolves on the laptop the server was provisioned from.

## Known gaps

* The original incident was never attributed. Neither the `To:` headers of the BCC'd copies nor the query above was read, so whether this was resend-looping or a distributed signup run is still open.
* There is no working way for a visitor to request a new verification email. `EmailAddressVerificationsController#create` exists and is throttled, but its only caller — the button in `app/views/email_address_verifications/show.html.erb` — posts to the member route without a token and would raise `UrlGenerationError`, and that template never renders because `#show` always redirects. Anyone whose send is suppressed therefore has no self-service recovery, which is tolerable only because nothing gates on verification.
* `EmailAddressVerificationsController#show` requires authentication, so a verification link opened in a different browser bounces to sign-in.
* Consider moving transactional mail to a dedicated sending subdomain so `afida.com` reputation cannot be damaged by this class of abuse at all.
