---
type: Proposal
description: Referral-rewards and prize design for The Afida Stack game, from a Hormozi offer audit — milestone rewards in things not percentages, status prizes, urgency; lists the four decisions founders need to make.
status: active
timestamp: 2026-08-28
---

# The Afida Stack: Growth Mechanics Proposal

The Afida Stack (afida.com/game, PR #292) is a 30-second browser stacking game built as a marketing loop: stack 15, win 5% off, challenge peers via score links, monthly top-10 leaderboard with Instagram handles. This proposal covers the peer-invite incentive layer, designed by running the offer through the Hormozi value-equation audit (companion to /proposals/money-model-2026-08.md and /proposals/leads-2026-08.md).

## Audit verdict in one paragraph

The game mechanics score high on the value equation (instant, effortless, deterministic win) but the prizes were abstractions. Percentages are weak dream outcomes: nobody screenshots "+1%". The fixes, in Hormozi priority order: make prizes tangible things, make referral rewards milestones toward things, pay the leaderboard crown in *status* (Instagram exposure — worth more than any discount to a café), and say the deadline out loud (the monthly reset was invisible urgency).

## What is already built (in PR #292)

- **Referral tracking**: every leaderboard entry gets a 6-char code; share links carry `ref=`; a *verified invite* = a replay-verified run from a different address than the referrer's (self-invites from the same IP earn nothing). Counts are on the admin page.
- **Invitee side of the offer**: arriving via an invite link drops the win threshold from 15 to 12 ("A mate greased the crane") — the link is worth something to the person receiving it, which is what makes people forward it.
- **Milestone copy** shown to players after they join the board:
  - 3 verified invites → free samples box (quote your code)
  - 5 verified invites → free case of cups with your next order (quote your code)
- **Urgency**: "resets in N days" on the board; "this month only" on the prize.
- **Tangible framing**: "You've won 5% off your next order — on a typical order that's a sleeve of cups on us."
- **Status**: "Top stacker this month gets a shoutout from @afidasupplies" on the board.

Fulfilment is deliberately manual for v1: the player quotes their code (email or order note), admin looks up the entry and sees the verified-invite count. No coupon automation needed until volume justifies it.

## The four decisions founders need to make

1. **Create the Stripe promotion code `STACK5`** (5% off). Recommend monthly expiry to match the "this month only" copy, recreated each month. Decide: first-order-only or open to repeat customers (recommend open — the co-founder's "win and get 5%" implies no restriction).
2. **Prize framing**: is "a sleeve of cups on us" acceptable copy for 5% off a typical order, or would you rather fulfil an actual free sleeve? (Actual product beats a discount on perceived value; costs roughly the same.)
3. **Referral milestones**: confirm the samples box at 3 invites (this is the existing free-samples funnel — each claim is a warm B2B lead) and the free case at 5 (real cost — needs a cap or "with your next order over £X" qualifier if concerned).
4. **The @afidasupplies shoutout**: commit to one story/post per month tagging the winning café. Near-zero cost, and for a B2B audience it is the strongest incentive on the page. Optional extra: a "Certified Stacker" till sticker dropped into the winner's next order.

## Deliberately not built

- Cash/credit per referral (incentive-spam magnet, needs fraud ops).
- Anything requiring signup before play (would kill the instant-play property the sharing depends on).
- Venue "crews" (cafés as teams recruiting staff/regulars) — the strongest escalation, but hold until referral numbers prove appetite.
