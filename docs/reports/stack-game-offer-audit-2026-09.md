---
type: Report
description: Hormozi value-equation audit of The Afida Stack's live commercial offer — prizes, referral gift, kickback, and crown — as shipped on 2026-09-02.
status: active
timestamp: 2026-09-02
---

# The Afida Stack: Offer Audit (September 2026)

Re-audit of the **live** commercial layer (not the August proposal's intent). Companion to [/proposals/stack-game-growth-2026-08.md](/proposals/stack-game-growth-2026-08.md), which already ran a first pass and then stripped the milestone ladder. This pass scores what a café actually sees on `/game` today.

This offer helps UK café and hospitality buyers get a tiny, time-boxed discount and a brag using a 30-second stacking game.

---

## 1. Offer Summary

- **Who it’s for:** UK foodservice buyers (cafés, hotels, takeaways) who already buy or might buy packaging. The URL is public, so anyone can play.
- **What it promises:**
  1. Stack 15 (12 via a mate’s link) → 5% off one order this month, over £100 excl. VAT.
  2. Join the board → Instagram on the public top 10 (once approved) and a share link that greases the crane for mates.
  3. One verified invite → an extra 5% `MATE` code, emailed, same £100 floor.
  4. Monthly #1 → a free case of cups + a shoutout from @afidasupplies.
- **How it works:** Instant play, no signup. Win code and kickback travel by email only. Codes are unique, single-use, month-expiring, capped at 200 redemptions each.
- **Price:** Free to play. The “prize” costs a £100+ stocking order to redeem. 5% of that floor is **£5**.

---

## 2. Overall Diagnosis

**The game is a strong advertisement. The prizes are a weak offer.**

Mechanics still crush the value equation: one button, ~30 seconds, deterministic win. That is why people will play. They will not *want* the commercial prize, because the hero promise is still a percentage, and the small print turns it into a fiver on a hundred-pound basket.

The August audit said the fix was “make prizes tangible things.” v1 then deleted the tangible referral ladder (samples box, free case) and kept 5%. The only photographable prize left is the monthly crown — one winner, and the two founder decisions that make it real are still unconfirmed on a live page that already promises them.

What works and must not be touched: instant play, email-as-delivery not bribe, gift-to-the-friend (15→12), unique codes, monthly clock said out loud.

---

## 3. Value Equation Analysis

Value = (Dream Outcome × Perceived Likelihood) / (Time Delay × Effort)

### Dream Outcome

- **Score:** 4 / 10
- **Issues:**
  - Live hero copy is still “5% off” / “Bonus 5% at 15” / “I stacked N and won 5% off”. Percentages are abstractions. Nobody screenshots “+5%”.
  - The proposal’s tangible framing (“a sleeve of cups on us”) is **not on the win card**. The win card says “5% off your next order”, then £100 excl. VAT in the terms.
  - 5% × £100 floor = **£5**. That is not a sleeve of cups. The dream and the maths contradict each other.
  - The actually-desirable outcomes for a café owner are (a) free stock they can photograph, (b) being seen by other cafés. Only the monthly #1 gets (a) and (b). Everyone else gets (almost nothing).
- **Fixes:**
  - Do not use a cup SKU (self-selects the wrong half of the book) and do not use the sample box as the *trophy*. Samples are already free on `/samples` (buyer pays delivery). Winning the default lead magnet looks like winning a sales call, not a prize. The sample box is the right **lead magnet** for the rest of the funnel; it is a weak **dream outcome** on a win screen.
  - SKU-agnostic things that still *look* like money or status: a round-pound credit (“£20 off any order this month”), a free case of whatever they actually stock (crown only — expensive), or the shoutout / board. Pick one trophy. Don’t make the trophy the thing they could have claimed without playing.
  - The live crown line (“a free case of cups”) has the same SKU bug. If the crown stays, make it “a free case of whatever you actually order” or a credit against any case. Put last month’s winner on the board, not a fineprint line.

### Perceived Likelihood

- **Score:** 5 / 10
- **Issues:**
  - Winning the *game* is believable (you just did it). Redeeming the *prize* is not: £100 excl. VAT this month, email delivery, unique code, checkout restriction. “You won” then “spend a hundred pounds” is a trust leak.
  - The crown (case + shoutout) is promised on the live page. Fulfilment is still a founder decision. One missed month and every prize on the page becomes fiction.
  - Instagram handles stay hidden until a human approves. The status prize looks empty on day one of a new month.
  - No proof anyone has ever redeemed a STACK code or received a shoutout. First players are buying a story.
- **Fixes:**
  - Confirm and perform the shoutout and the case, then put last month’s winner on the board (“August: @sohocoffee — case shipped”).
  - On the win card, one sentence that names a real checkout path: “Code STACK••••, £100+ order, this month, at afida.com.” (Code stays in email; the *path* is what must feel inevitable.)
  - Auto-approve clean handles is already built — keep it. Empty-board month needs a seed (Afida staff run, labelled) so the status prize is visible.

### Time Delay

- **Score:** 8 / 10 (game) / 4 / 10 (prize)
- **Issues:**
  - First win in the game: under a minute. Excellent.
  - First *commercial* win: whenever they next place a £100 order, before month-end. If they are not restocking this week, the code dies. Time delay on the dream is “your next big order, maybe never.”
  - Kickback delay is actually good: push email the moment a mate plays. Don’t touch that.
- **Fixes:**
  - Make the win prize usable on a smaller basket **or** extend expiry to 60 days so it lands on a real restock cycle.
  - Add a same-session CTA that is a win without checkout: claim a sample box (they pick the lines). That is the book’s lead magnet, it pays out this week, and it does not assume cups.

### Effort & Sacrifice

- **Score:** 9 / 10 (play) / 5 / 10 (the loop you actually want)
- **Issues:**
  - Play is one button. Correct, do not add a gate.
  - The viral loop you want is: win → share a gifted link. To gift the crane the player must join the board *and* leave an email. That is a second form, behind a fold, after the prize card. Extra steps on the one behaviour that makes the game an advertisement.
  - Redeeming 5% requires a stocking order. High sacrifice relative to a £5 outcome.
- **Fixes:**
  - Issue the `ref` code on the win-claim email itself, not only on board join. Share link in the same email: “Forward this — they win at 12.” That is the two-sided gift with zero extra form.
  - Keep board join for status (Instagram). Don’t hold the gift-link hostage to it.

---

## 4. Market Fit

- **Issues:**
  - Avatar is right: cafés who buy packaging, AOV around £100, restock cadence measured in weeks. The £100 floor matches a real basket.
  - Distribution is wrong: a public arcade will be played by staff, friends, and people who will never order £100 of kraft. The share text (“won 5% off at afida.com”) travels into that crowd. They bounce on the small print. The café owner — the one who can pay — may never see the link if the player is a barista.
  - The Leads proposal already named the actual engaged-lead event: **a sample request**. The game does not produce one. It produces a coupon and an email. That is a colder lead than the sample box.
- **Fixes:**
  - Aim the share ask at “send this to the person who orders the cups,” not “challenge a mate.”
  - On win, offer the sample box as the default give (they pick cups, lids, boxes, napkins — whatever they actually use), with a checkout code as the upsell for people who already buy. Sample request = engaged lead. Coupon = maybe.

---

## 5. Offer Structure

Three offers are stacked in one cabinet, and only the first is complete:

| Layer | Promise | Complete? |
| --- | --- | --- |
| Play | Fun, 30s, no signup | Yes |
| Win prize | 5% / £100 / this month | Incomplete: abstract, tiny, gated |
| Referral | Gift 12-stack + extra 5% | Gift is good; kickback is another abstract 5%; extra form |
| Crown | Case + shoutout | Promised, fulfilment unconfirmed |

- **Issues:** Hormozi’s Grand Slam needs a named offer, a tangible stack, a guarantee, and a reason to act now. The game has a name and a clock. It does not have a named commercial offer (“The Stacker’s Sleeve”, “The Greased Crane”). Players cannot tell which prize is *for them*.
- **Fixes:** Pick one primary commercial offer per screen. Menu = play + crown. Win = one tangible give. Share = gift to a friend. Stop repeating “5%” in four places as if it were four prizes.

---

## 6. Value Stack

- **Issues:**
  - No stack is shown. There is a rate, a floor, and an expiry. No “worth £X”, no bonus that is a different *kind* of thing.
  - August’s stack (3 invites → samples, 5 → case) was the only product-denominated ladder. It was removed. What remains is two flavours of 5% and one lottery case.
  - Hormozi’s referral rule from the Leads proposal: *two-sided, product-denominated* (“give a sleeve, get a sleeve”). The game does two-sided *ease* (12 vs 15) plus two-sided *percentage*. Ease is clever. Percentage is not a sleeve.
- **Fixes:**
  - Restore one product rung on the referrer side: first verified invite → sample box. Not a sleeve of cups — the box is how Afida already lets a buyer choose the lines they actually use. That is the lead magnet the rest of the Hormozi trilogy already agreed on.
  - Keep 15→12 as the invitee gift. That is the rare part of this design that is actually Grand Slam (a gift they can give).
  - Kill or demote the `MATE` extra-5%. A second percentage does not stack; it discounts the first one.

---

## 7. Pricing

- **Issues:**
  - The giveaway is priced as 5% because that is a round coupon, not because it matches an outcome. Against £96 historical AOV it is ~£5. Against a case of cups it is a rounding error.
  - The £100 floor is honest commercially (nudge a real order, match free-delivery) and fatal to the “you won” feeling. You cannot sell a win that requires a hundred-pound checkout.
  - 200 redemptions/month × £5 = £1,000/month worst-case giveaway. Cheap. So cheap it signals the prize is cheap.
- **Fixes:**
  - If the budget is ~£1,000/month, spend it on **~20 sample boxes**, not 200 fivers. Scarcer, photographable, on-avatar, SKU-agnostic.
  - Anchor in public: “Pick five lines. We’ll send them. Then 5% off when you stock up, if you want.” Never lead with 5%.
  - Do not raise the percentage. Change the unit.

---

## 8. Messaging

- **Issues:**
  - Menu: “Bonus: stack 15 for 5% off.” Rate, not thing.
  - Win card: “Bonus unlocked: 5% off your next order” then the £100 line. The objection is in the terms, not handled.
  - Share: “won 5% off at afida.com” / “Crane’s greased — you win the 5% at 12.” The gift is the interesting line; it is buried under the percentage brag.
  - Crown: one fineprint sentence, no picture, no last-month winner.
  - Brand voice in the quips is good. Prize voice is coupon-site.
- **Fixes:**
  - Menu: “Stack 15. We’ll send a sample box of whatever you actually use.”
  - Win: “Pick five lines — cups, boxes, napkins, doesn’t matter. They’re on us.”
  - Share: lead with the gift. “I greased the crane — you win at 12. Beat 18.”
  - Board: “Last month @x got a case and a story. Resets in N days.”

---

## 9. Objections & Trust

| Objection | Handled? |
| --- | --- |
| “Is this a real discount or a gag?” | Weakly. Unique code + Stripe is real; 5% + £100 feels like a gag. |
| “Will you actually shout anyone out / send a case?” | No. Promised, not evidenced. |
| “You’ll spam me.” | Yes. Unticked marketing box, email is delivery. Keep this. |
| “I have to sign up to play.” | Yes. You don’t. Keep this. |
| “The code won’t work / will sit in spam.” | Partially. Send-again resends the same code. No guarantee copy. |
| “I’m not ordering £100 this month.” | Not handled. This is the silent killer. |

- **Fixes:**
  - Fulfil the crown once, in public.
  - A one-line guarantee on the win email: “If checkout rejects the code this month, reply and we honour it.” Cheap, because volume is capped.
  - An alternative redeem path for people under £100: sample box. Turns the objection into the actual lead magnet.

---

## 10. Top Priority Fixes

1. **Stop selling 5%.** Change the unit to something that looks like money or status and works for any SKU: a round-pound credit (“£20 off this month”) and/or the crown/shoutout. Not a sleeve of cups (wrong half of the book). Not a sample box as the trophy (already free on `/samples` — winning it looks like a sales call). Keep samples as the lead magnet elsewhere; don’t make them the win screen.
2. **Confirm and show the crown.** One case, one tagged story, last-month winner on the board. Or take the promise off the page. A live lie here poisons the rest.
3. **Put the gift-link in the win email.** Don’t make board-join the price of being able to grease the crane. The 15→12 gift is the only Grand Slam piece; get it out of the fold.
4. **Replace the MATE extra-5% with a product rung** (first verified invite → sample box). That is the Leads proposal’s referral mechanic, which this game currently ignores.
5. **Aim the share ask at the buyer**, not “a mate.” Baristas play; owners order.

---

## 11. Quick Wins

Do these without new product:

- Rewrite the four “5%” strings (menu prize line, HUD pill, win card, share text) to the sample box, even if a coupon stays in the email for a week. Same pass: the crown line cannot say “case of cups” if the winner runs a pizza shop.
- Add last-month winner + photo slot on the board (can be a static sentence until the first real one).
- Add the greased-crane URL to `GameMailer#win_code`.
- Change share preview to lead with the gift, not the percentage.
- Decide the two founder items (case + shoutout) this week. Ship or remove.

Do not:

- Add signup-before-play.
- Add cash-per-referral.
- Bring back a 3-rung ladder before one product rung is converting.
- Raise 5% to 10% as if the problem were the number.

---

## Severity snapshot

| Weak point | Severity |
| --- | --- |
| Dream outcome is a percentage, worth £5 | Critical |
| Crown promised, fulfilment unconfirmed | Critical if unconfirmed |
| Prize requires £100 checkout | High |
| Gift-link locked behind board join + email | High |
| Referral kickback is a second 5% | Medium |
| Share targets “mates”, not buyers | Medium |
| No proof anyone has won a real prize | Medium |
| Instant play, email-as-delivery, 15→12 gift, unique codes, monthly clock | Keep |
