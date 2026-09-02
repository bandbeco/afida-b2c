---
type: Proposal
description: Referral-rewards and prize design for The Afida Stack game, from a Hormozi offer audit — v1 ships unique single-use prize codes, the gift-link loop, a referral kickback, email lead capture, and an Instagram shoutout crown; milestone ladders are deferred.
status: active
timestamp: 2026-09-02
---

# The Afida Stack: Growth Mechanics Proposal

The Afida Stack (afida.com/game, PR #292) is a 30-second browser stacking game — a Rails page at `GamesController#show`, not a static file — built as a marketing loop: stack 15, win £10 off a £100+ order, challenge peers via score links, monthly top-10 leaderboard with Instagram handles. This proposal covers the peer-invite incentive layer, designed by running the offer through the Hormozi value-equation audit (companion to /proposals/money-model-2026-08.md and /proposals/leads-2026-08.md).

## Audit verdict in one paragraph

The game mechanics score high on the value equation (instant, effortless, deterministic win) but the prizes were abstractions. Percentages are weak dream outcomes: nobody screenshots "+1%". The fixes, in Hormozi priority order: make prizes tangible things, make referral rewards milestones toward things, pay the leaderboard crown in *status* (Instagram exposure — worth more than any discount to a café), and say the deadline out loud (the monthly reset was invisible urgency).

## What is already built (in PR #292)

- **Referral tracking**: every leaderboard entry gets a 6-char code; share links carry `ref=`; a credited referrer is a replay-verified run from a different IP than the referrer's (self-invites earn nothing). Admin shows the chain. The public share code is not a capability: a later win-claim email attaches to this IP's latest board entry, never to someone else's `ref=`.
- **Invitee side of the offer**: arriving via an invite link drops the win threshold from 15 to 12 ("A mate greased the crane") — the link is worth something to the person receiving it, which is what makes people forward it.
- **Urgency**: "resets in N days" on the board; "this month only" on the prize.
- **Tangible framing**: "You've won £10 off your next £100+ order."
- **Unique single-use prize codes, delivered by email only** (no fixed `STACK5` anywhere, and no code ever shown on screen): the win screen asks where to send the code; `/game/win_code` re-verifies the drop log through `Game::VerifiedRun` (the same proof as a leaderboard submission), captures the lead, mints a Stripe promotion code (`STACK` + 6 chars, **£10 off**, `max_redemptions: 1`, expiring with the month, valid on orders over £100 excl. VAT), and emails it. One code per address per month is stored on `game_leads`; "Send again" resends that code rather than minting another.
- **Referral kickback**: when a referred address places their **first paid order of £100+ excl. VAT**, a job mints a single-use £10-off `MATE` code, stores it on `game_leads.mate_promo_code`, and emails the referrer. One payout per referred email. Play-through alone does not pay. A retry resends the stored code. The code needs *an* email to travel (win claim or board join — the board field is not special); if none is on file yet, the payout waits and flushes when one arrives. Copy: “Stack another £10 for each business that orders.” (venues, not cafés only — restaurants, hotels, and the rest of hospitality count).
- **Play token**: issued once on `GamesController#show`. `GET /game/leaderboard` returns entries only, so a board refresh cannot mint a new token and reject a real win as `too_fast`. Win thresholds (15 / 12) live on `Game::PromoCodes` and travel in the page boot payload.
- **Status crown**: "Top stacker this month wins a shoutout from @afidasupplies" on the board. The handle links to the Instagram account. No free case.
- **Email capture, as delivery rather than bribe**: the win claim and the optional board-join email (never in the public payload — regression-tested) are the two capture points; the dethroned #1 gets an email pulling them back to defend the crown. Every address lands in `game_leads` with a separate, unticked "Send me Afida offers too" opt-in (UK PECR). Opting in writes an `EmailSubscription` and emits `email_signup.completed`, so Klaviyo actually sees the lead. The admin leaderboard lists prize-claim emails (including winners who never joined the board) alongside entries for crown fulfilment.

## The decision founders still need to make

1. **The @afidasupplies shoutout**: the crown is the shoutout only — no free case. Commit to one story/post per month tagging the winning venue. Near-zero cost, and for a B2B audience it is the strongest incentive on the page. Optional extra: a "Certified Stacker" till sticker dropped into the winner's next order.

Nothing to create in Stripe: the coupons mint themselves as £10 off. Worth a skim of the numbers, though — the 200-redemptions-per-coupon monthly cap in `Game::PromoCodes::MONTHLY_REDEMPTION_CAP` is the giveaway ceiling, adjustable in one place.

## Deferred: referrer-side milestone ladder (2026-08-31)

The v1 direction is *keep it simple, optimise for virality* — and the share motivator in this design is the gift (the invitee's greased crane) plus the single kickback rung above, not a reward ladder. The milestone copy (3 verified invites → samples box, 5 → free case of cups) has been removed from the game. The server still attributes `ref=` arrivals and counts verified invites on the admin page, so the numbers to justify reintroduction keep accruing. Revisit when verified invites show players actually chain referrals; the samples-box rung doubles as the free-samples lead funnel when it comes back, and the free-case rung needs a cap or "with your next order over £X" qualifier.

## Deliberately not built

- Cash/credit per referral (incentive-spam magnet, needs fraud ops).
- Anything requiring signup before play (would kill the instant-play property the sharing depends on).
- Venue "crews" (cafés as teams recruiting staff/regulars) — the strongest escalation, but hold until referral numbers prove appetite.
