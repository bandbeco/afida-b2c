---
type: Proposal
description: Referral-rewards and prize design for The Afida Stack game, from a Hormozi offer audit — v1 ships unique single-use prize codes, the gift-link loop, a referral kickback, email lead capture, and a case-of-cups crown; milestone ladders are deferred.
status: active
timestamp: 2026-08-31
---

# The Afida Stack: Growth Mechanics Proposal

The Afida Stack (afida.com/game, PR #292) is a 30-second browser stacking game built as a marketing loop: stack 15, win 5% off, challenge peers via score links, monthly top-10 leaderboard with Instagram handles. This proposal covers the peer-invite incentive layer, designed by running the offer through the Hormozi value-equation audit (companion to /proposals/money-model-2026-08.md and /proposals/leads-2026-08.md).

## Audit verdict in one paragraph

The game mechanics score high on the value equation (instant, effortless, deterministic win) but the prizes were abstractions. Percentages are weak dream outcomes: nobody screenshots "+1%". The fixes, in Hormozi priority order: make prizes tangible things, make referral rewards milestones toward things, pay the leaderboard crown in *status* (Instagram exposure — worth more than any discount to a café), and say the deadline out loud (the monthly reset was invisible urgency).

## What is already built (in PR #292)

- **Referral tracking**: every leaderboard entry gets a 6-char code; share links carry `ref=`; a *verified invite* = a replay-verified run from a different address than the referrer's (self-invites from the same IP earn nothing). Counts are on the admin page.
- **Invitee side of the offer**: arriving via an invite link drops the win threshold from 15 to 12 ("A mate greased the crane") — the link is worth something to the person receiving it, which is what makes people forward it.
- **Urgency**: "resets in N days" on the board; "this month only" on the prize.
- **Tangible framing**: "You've won 5% off your next order — on a typical order that's a sleeve of cups on us."
- **Unique single-use prize codes, delivered by email only** (no fixed `STACK5` anywhere, and no code ever shown on screen): the win screen asks where to send the code; `/game/win_code` re-verifies the drop log with `Game::StackReplay` exactly like a leaderboard submission, mints a Stripe promotion code (`STACK` + 6 chars, `max_redemptions: 1`, expiring with the month, valid on orders over £100 excl. VAT — matching the free-delivery threshold so the prize nudges a real stocking order), emails it, and captures the lead in one motion. Codes exist only in Stripe and the winner's inbox — nothing for a coupon site to scrape, and every claim is a lead. The two 5% coupons auto-create per month, capped at 200 redemptions each — a hard ceiling on what even scripted minting could give away. Nothing to set up manually.
- **Referral kickback, one rung, pure push**: when someone a player sent verifiably plays (distinct-address, replay-verified), a background job mints their single-use extra-5% `MATE` code and emails it to the address they left at board join — no claim UI anywhere. One per board entry per month. A sharer who left no email isn't promised a kickback, and the share-screen copy only offers it when it can be delivered.
- **Status crown**: "Top stacker this month wins a free case of cups + a shoutout from @afidasupplies" on the board.
- **Email capture, as delivery rather than bribe**: the win claim and the optional board-join email (never in the public payload — regression-tested) are the two capture points; the dethroned #1 gets an email pulling them back to defend the crown. Every address lands in `game_leads` with a separate, unticked "Send me Afida offers too" opt-in (UK PECR); the admin leaderboard shows entry emails for crown fulfilment.

## The two decisions founders need to make

1. **The crown prize**: the board now promises the monthly winner a free case of cups on top of the shoutout — confirm the fulfilment (one DM and one case a month; winners' Instagram handles are on the board). A case is photographable in a way a discount never is, which is the point.
2. **The @afidasupplies shoutout**: commit to one story/post per month tagging the winning café. Near-zero cost, and for a B2B audience it is the strongest incentive on the page. Optional extra: a "Certified Stacker" till sticker dropped into the winner's next order.

Nothing to create in Stripe: the coupons mint themselves at 5%. Worth a skim of the numbers, though — the 200-redemptions-per-coupon monthly cap in `Game::PromoCodes::MONTHLY_REDEMPTION_CAP` is the giveaway ceiling, adjustable in one place.

## Deferred: referrer-side milestone ladder (2026-08-31)

The v1 direction is *keep it simple, optimise for virality* — and the share motivator in this design is the gift (the invitee's greased crane) plus the single kickback rung above, not a reward ladder. The milestone copy (3 verified invites → samples box, 5 → free case of cups) has been removed from the game. The server still attributes `ref=` arrivals and counts verified invites on the admin page, so the numbers to justify reintroduction keep accruing. Revisit when verified invites show players actually chain referrals; the samples-box rung doubles as the free-samples lead funnel when it comes back, and the free-case rung needs a cap or "with your next order over £X" qualifier.

## Deliberately not built

- Cash/credit per referral (incentive-spam magnet, needs fraud ops).
- Anything requiring signup before play (would kill the instant-play property the sharing depends on).
- Venue "crews" (cafés as teams recruiting staff/regulars) — the strongest escalation, but hold until referral numbers prove appetite.
