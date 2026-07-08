---
type: Plan
description: Controlled 90-day social media trial aimed at UK B2B buyers, LinkedIn first, with success criteria defined up front.
status: active
timestamp: 2026-07-05
---

# Afida — Lightweight 90-Day Social Media Plan

_Drafted 2026-07-04. A test, not a rebrand: prove whether social sends qualified UK B2B traffic and lifts brand recall, cheaply, before committing real time._

## The premise

Afida gets almost no social traffic **because it isn't present there** — not because social can't work. This plan is a controlled 90-day trial to find out. It is aimed at **B2B buyers** (café / restaurant / coffee-shop owners and their procurement), not consumers, because that is who actually buys and who our best-ranking content ("sustainable packaging for restaurants", pos ~2.8) already speaks to.

**What success looks like** is defined up front (see Measurement) so we don't move the goalposts. If it works, we scale. If it's the next £0 straws bucket, we'll know by day 90 and stop cleanly.

## Guardrails (learned from the analytics)

- **UK-first.** ~42% of Afida's traffic can't buy (UK-only shipping). Don't chase global reach; skew targeting, hashtags and topics UK.
- **Buyer intent over awareness.** Consumer awareness traffic (straws, blog) already converts ~£0. Lead with supplier/procurement angles, not lifestyle content.
- **Mobile is the weak conversion surface.** Social traffic is mobile-heavy and lands on our worst-converting surface. Send clicks to specific, mobile-tested pages (category/collection), never the generic homepage.
- **Assisted, not last-click.** Social's job here is mostly to feed **Brand / Direct** (already our #1 revenue channel) and to be a credibility signal for buyers vetting a supplier. Judge it partly on leading indicators, not only last-click revenue.

## Channels (ranked by fit, not popularity)

| Priority | Channel | Why | Cadence |
|---|---|---|---|
| **1** | **LinkedIn** | Where B2B buyers, café/restaurant owners, sustainability & procurement people are. Best match for our proven B2B angle. | 3×/week |
| **2** | **Pinterest** | Packaging is visual + Pinterest carries genuine purchase intent and long content half-life; boards get re-saved. | 3×/week (mostly recycled catalog imagery) |
| **3** | **Instagram** | Less for direct sales, more for **credibility** — a buyer checking "is this a real, active company." Fixes the "looks inactive" trust cost. | 2×/week |
| **4** | **Google Business Profile** | Free, local/branded search trust signal. Not "social" but adjacent and near-zero effort. | Set up once, occasional posts |

Skip TikTok / X / Threads for the trial. Wrong audience or too much effort for the return; revisit only if LinkedIn proves the concept.

## Content mix (all from assets we already have — near-zero new production)

Roughly the **70 / 20 / 10** rule, weighted to what we can produce cheaply:

- **50% — Repurposed blog** (auto-syndicated). We have 16+ production posts. Postiz RSS auto-posts each new/existing article. Zero marginal effort.
  - _Examples we already own:_ startup costs for a coffee shop, can you recycle pizza boxes, paper napkins, sustainable food packaging.
- **20% — Product / catalog spotlights.** One category or family per post, tied to a **proven B2B search angle** so social and SEO reinforce each other:
  - NatureFlex compostable bags (we're the official stockist — wasted authority)
  - Vegware cups & range (official stockist)
  - Soup containers, ice-cream cups, wooden/birchwood cutlery, kraft/pizza boxes
  - Always the "**[product] for restaurants / cafés**" framing.
- **20% — Credibility / educational.** "Is it actually compostable vs recyclable", "PLA vs aqueous-lined cups", stockist authority, free-samples offer (samples are free, customer pays delivery). Positions Afida as the knowledgeable UK eco-supplier.
- **10% — Behind-the-brand / proof.** New products, a customer's branded packaging, "official Vegware stockist" trust posts. Light, occasional.

Every post links to a **specific commercial page** (the NatureFlex, Vegware, soup, ice-cream, cutlery category/collection pages we've already SEO-hardened), never the homepage.

## Voice — tongue-in-cheek deadpan (non-negotiable)

Every post uses the site's existing brand voice. Not a new social persona — the **same dry, deadpan register already in the product/category copy**. It's the brand's biggest differentiator against the beige "eco packaging supplier" crowd, so it carries across to social unchanged.

**The reference lines (real site copy — this is the target):**
- Soup containers: _"Boxes, containers, and trays that hold your food and your reputation together."_
- Hot cups: _"These are compostable, sturdy, and won't embarrass your coffee."_
- Napkins: _"They do the job and then they disappear. As napkins should."_
- NatureFlex: _"Clear, crinkly and made from wood-pulp cellulose, not plastic."_

**The formula:** plain-spoken fact **+ one deadpan turn, delivered straight.** It undersells rather than hypes. It's confident enough to be brief. It never explains the joke.

**Do:**
- Short, declarative lines. Confidence through brevity.
- One dry twist, usually at the end (_"Ambitious, for a bag."_ / _"That's the whole pitch."_).
- Deadpan self-awareness beats hype (_"Free samples if you're sceptical (you should be)."_).
- Understatement over adjectives.

**Don't:**
- No hype words (game-changing, revolutionary, amazing, eco-warrior), no exclamation-mark stacking.
- Don't over-explain or wink at the joke. Deliver it flat and move on.
- Don't get earnest/salesy ("you don't have to compromise!") — that's the voice we're avoiding.

**Per-channel dial:** LinkedIn = a real B2B post with one or two dry beats inside it. Instagram = the deadpan basically _is_ the caption. Same voice, different volume.

**Worked example (NatureFlex, one product → two channels):**

- _LinkedIn:_ **"A bag that shows off your baking and then quietly composts. Ambitious, for a bag."** … [B2B body: wood-pulp not plastic, official UK stockist, range, from £48/case, free samples] … closes: **"Clear as plastic. Not plastic. That's the whole pitch."**
- _Instagram:_ **"Clear as plastic. Kind as compost. Suspiciously well-behaved. 🥖"** … short body … **"Free samples if you're sceptical (you should be). Link in bio."**

When drafting a batch (human or AI-assisted), check each post against the four reference lines above. If it reads like any other packaging supplier, it's wrong.

## Tooling

- **Self-hosted Postiz** on the existing Kamal stack (near-free; same features as the $29–99/mo hosted tiers). One calendar, cross-post + per-channel tweak, AI drafting, analytics.
- **RSS auto-posting** from the Afida blog feed → handles the 50% blog slice automatically from day one.
- **MCP server** means posts can be drafted programmatically (I can help produce the weekly batch from the catalog + blog).

### Imagery — AI for graphics, real photos for products

Postiz can generate images, but **how** matters for a brand selling physical, real products.

- **How it works:** Postiz's image generation calls **OpenAI** (`chatgpt-image-latest`, the current GPT-image/DALL-E model) at 1024×1024 or 1024×1536 (vertical for Instagram). The AI caption copilot uses GPT-4.1. Both are gated behind a single env var, **`OPENAI_API_KEY`** — the copilot literally disables itself if it's absent.
- **Self-hosting cost note:** the "300 images/month" credits are a **hosted-plan** thing. Self-hosted, **we supply our own OpenAI key and pay OpenAI directly** (a few cents per image). At ~8 Instagram posts/month that's pennies to low single-digit £/month — trivial, but not zero, and the key must be wired in at setup.
- **Use AI for:** deadpan quote/text cards (e.g. _"Holds your soup. Holds your reputation. No pressure."_), abstract compostable/natural backgrounds, seasonal graphics. AI can't misrepresent a product here.
- **Do NOT use AI for:** fake photos of the actual products. AI-generated packaging shots look plausible-but-wrong (invented logos/textures) and would undercut the "official stockist, real thing, boringly" credibility the [voice](#voice--tongue-in-cheek-deadpan-non-negotiable) is built on. **Real product photography wins** — even phone shots of real stock.
- **Hybrid is fine:** real product photo + AI background or a text overlay via the built-in picture editor.
- **The features that pull the most weight for Afida are RSS auto-posting and copilot caption drafting**, not the image generator.

## 90-day timeline

**Phase 1 — Setup & baseline (Weeks 1–2)**
- Stand up self-hosted Postiz on Kamal; connect LinkedIn, Pinterest, Instagram; set up Google Business Profile.
- Wire blog RSS → auto-post. Record a **baseline** in Datafa.st (current social sessions ≈ 0 — this is our zero line).
- Draft the first 3 weeks of posts in one batch (blog auto-fills; write ~8 product/credibility posts).

**Phase 2 — Consistent cadence (Weeks 3–8)**
- Run the full cadence (LinkedIn 3×, Pinterest 3×, Instagram 2× per week).
- Weekly: batch-draft the coming week from catalog + blog (½ hour with AI assist).
- **Week 6 mid-point check:** which channel/posts drive any UK clicks or engagement? Kill dead formats early; lean into what moves.

**Phase 3 — Read the signal & decide (Weeks 9–12)**
- Keep cadence; double down on the best-performing 1–2 channels.
- **Day-90 review** against the metrics below → decide: **scale, adjust, or stop.**

## Measurement — decided now, not later

Track weekly in Datafa.st (social shows as its own referrer) + native platform insights.

**Primary (does it send qualified buyers?)**
- UK social sessions/week (trend from the ~0 baseline)
- Social → category/collection page depth (not bounce-and-leave)
- Any social-attributed conversions or free-sample requests

**Leading indicators (is it building the asset?)**
- Follower + engagement growth per channel
- **Brand / Direct traffic trend** (social's real payoff is feeding our #1 channel — watch for lift alongside social growth)
- LinkedIn post impressions to café/restaurant/procurement audiences

**Day-90 decision rule (illustrative — tune the numbers with Tariq):**
- **Scale** if social is a growing source of UK sessions landing on commercial pages AND/OR Brand/Direct is trending up alongside it.
- **Adjust** if one channel clearly works and the others don't → drop the losers, reinvest.
- **Stop** if after a fair 90-day run social sends negligible qualified UK traffic and shows no assisted lift.

## The honest cost

- **Tooling:** ~free (self-hosted) + a little infra.
- **Setup:** ~1–2 days (Postiz + channel connections + first content batch).
- **Ongoing:** ~30–45 min/week to batch-draft and review. **This weekly habit is the real commitment** — distribution is automated, but "growing on social" needs a steady trickle of posts someone conceives. AI drafting from our own catalog/blog keeps it small, but it isn't zero.

## Open questions for Tariq

1. **Do Afida's actual buyers use social to find suppliers?** For packaging procurement the honest answer is often "not much — they Google or reorder direct." A quick gut-check on how current customers found Afida would sharpen (or redirect) this whole bet.
2. **Who owns the weekly habit?** I can draft batches, but someone needs to approve, add the human touch, and reply to comments/DMs — social is two-way.
3. **Comfortable with the day-90 stop rule?** The value of a trial is being willing to end it. Agreeing the exit criteria now keeps this cheap.

## Appendix — Example post bank

Three worked product spotlights in the locked [voice](#voice--tongue-in-cheek-deadpan-non-negotiable), each drafted for LinkedIn (B2B, one or two dry beats) and Instagram (deadpan _is_ the caption). Specs and prices are real (pulled from production 2026-07-05). Together they cover the three core B2B angles — bakery/deli, takeaway, coffee-shop — and each links to an SEO-hardened commercial page. Use as the template for weekly batches.

### 1. NatureFlex bags — _(bakery / deli)_ → `/categories/bags-and-wraps/natureflex-bags`

**LinkedIn**
> **A bag that shows off your baking and then quietly composts. Ambitious, for a bag.**
>
> Most clear bags are plastic pretending to be harmless. NatureFlex isn't. It's made from wood-pulp cellulose, so your bloomers and baguettes stay perfectly on show, and the bag goes in the home compost when it's done its job.
>
> We're an official UK stockist, so we keep the whole range on the shelf:
> • Bloomer and baguette bags, with a gusset if you need the depth
> • Glassine bags with a NatureFlex window, grease-resistant, for the savoury stuff
> • Multi-bags for when you can't decide
>
> From £48 a case. Free samples if you'd rather not take our word for it. You just cover the delivery.
>
> Clear as plastic. Not plastic. That's the whole pitch.
>
> #SustainablePackaging #FoodPackaging #CompostablePackaging #UKHospitality

**Instagram**
> **Clear as plastic. Kind as compost. Suspiciously well-behaved. 🥖**
>
> NatureFlex bags are made from wood pulp, not oil. Your bakes stay on show, the bag composts at home, nobody has to feel guilty about the window.
>
> Official UK stockist. Free samples if you're sceptical (you should be). Link in bio.
>
> #ecopackaging #compostable #plasticfree #bakerylife #cafeuk #zerowaste #artisanbakery #shopsmalluk

### 2. Soup containers — _(takeaway)_ → `/categories/hot-food/soup-containers`

**LinkedIn**
> **Soup is only as good as the container it survives the journey in.**
>
> A container that leaks in the bag doesn't just ruin a lunch. It ruins the review.
>
> Our soup containers are kraft, biodegradable, and built to hold hot food and your reputation together. Matching lids that actually stay on. Sizes from single servings up to the ones that feed a table.
>
> • 90 and 115 series, with lids to match
> • Kraft board, biodegradable, compostable
> • From £35 a case, free UK delivery over £100
>
> Free samples if you'd like to fill one with something hot and see for yourself.
>
> #SustainablePackaging #FoodPackaging #Takeaway #UKHospitality

**Instagram**
> **Holds your soup. Holds your reputation. No pressure. 🍲**
>
> Kraft, biodegradable, and the lid actually stays on, which is more than can be said for most.
>
> Sizes from a modest cup to a serious bowl. Free samples if you want to stress-test one. Link in bio.
>
> #ecopackaging #compostable #takeawaypackaging #soup #cafeuk #zerowaste #foodtogo #shopsmalluk

### 3. Vegware cups — _(coffee-shop)_ → `/collections/vegware`

**LinkedIn**
> **The official Vegware cups, from an official Vegware stockist. Refreshingly boring provenance.**
>
> Double-wall, so the cup insulates the coffee and not your customer's hand. Plant-based, certified compostable to EN 13432, which is the standard that actually means something.
>
> We keep the range on the shelf so you're not waiting on a back-order to open on Monday:
> • Feel Snug and BlueStripe double-wall hot cups, 8oz to 16oz
> • rPET cold cups for the iced-drink season
> • Matching lids (sold separately, as they always are)
>
> From £29.82 a case. Free samples if your baristas want to hold one first.
>
> #Vegware #CompostablePackaging #CoffeeShop #SustainablePackaging #UKHospitality

**Instagram**
> **The Vegware cup that insulates the coffee, not your hand. 🌱**
>
> Double-wall. Plant-based. Compostable to EN 13432, which is the certification that isn't just a nice logo.
>
> Official UK stockist, so it's the real thing, boringly. 8oz to 16oz, hot and cold. Link in bio.
>
> #vegware #compostablecups #coffeeshop #ecopackaging #baristalife #plantbased #cafeuk #shopsmalluk
