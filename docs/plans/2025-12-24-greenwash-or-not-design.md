# Greenwash or Not? - Design Document

**Date:** 2025-12-24
**Status:** Draft
**Effort:** 2 weeks (Full scope)

## Overview

**Greenwash or Not?** is an interactive tool that helps users identify misleading environmental claims on food packaging. It combines a viral swipe-game with a serious certification checker and generates citable research data for PR and backlink acquisition.

### The Problem

The UK food packaging market is flooded with vague environmental claims. Terms like "eco-friendly," "biodegradable," and "plant-based" sound green but often mean nothing - or worse, mislead buyers into thinking products are compostable when they'll sit in landfill for decades. Real certifications exist (Seedling logo, OK Compost, Home Compostable), but most people can't distinguish them from marketing fluff.

### The Solution

A three-layer tool:

1. **The Game** - Tinder-style swipe interface. Users see a packaging claim or certification logo and swipe right (legit) or left (greenwash). After each swipe, a reveal explains the truth - including surprising "but..." twists that make even correct answers educational.

2. **The Checker** - A searchable database where businesses can verify specific certifications or claims before purchasing from suppliers.

3. **The Report** - Aggregated data from Afida's research and player results, published as "The UK Greenwash Report" - a citable resource for journalists writing about sustainability claims.

### Why This Works for Afida

- **Linkability**: Journalists cite the research and link to the tool
- **Authority**: Positions Afida as the honest broker in a confusing market
- **Lead generation**: Business users discovering the checker are your target customers
- **Differentiation**: Competitors sell products; Afida helps customers make informed choices

### SEO Context

This tool is designed for **backlink acquisition**, not direct search traffic. Keyword research showed:

- Calculator/tool searches ("packaging calculator", "party supplies calculator") have near-zero UK search volume
- Competitor blog content earns almost no backlinks (1-2 referring domains per post)
- What DOES earn links: being a citable reference that journalists quote

The game creates shareable moments; the report provides citable statistics.

---

## The Game Mechanic & User Flow

### Entry Point

Users land on a simple page: "**Can you spot greenwashing?**" with a prominent "Play Now" button. No signup required - friction kills virality.

### The Swipe Interface

Each round presents a card showing:
- A certification logo OR a marketing claim (e.g., "100% Biodegradable")
- The type of packaging it appears on (e.g., "coffee cup", "takeaway box")

Users swipe:
- **Left** = Greenwash (misleading or meaningless)
- **Right** = Legit (genuinely certified compostable)

### The Reveal (The Magic)

After each swipe, the card flips to show:

1. **Verdict**: Correct or Wrong
2. **The Truth**: One-sentence explanation
3. **The "But..."**: A surprising twist that educates even when they got it right

**Example reveals:**

> **Claim:** "Biodegradable"
> **Verdict:** GREENWASH - You got it!
> **Truth:** "Biodegradable" has no legal definition. A plastic bag is technically biodegradable - in 500 years.
> **But...** Even certified compostable items often end up in landfill because most UK councils don't accept them.

> **Claim:** Seedling logo
> **Verdict:** LEGIT - You got it!
> **Truth:** The Seedling logo means certified industrially compostable under EN 13432.
> **But...** Only 54 UK councils collect food-soiled compostable packaging. Check if yours does.

### End of Game

After 10 cards:
- Show score: "You got 7/10"
- Personalised message based on score
- Share buttons (Twitter/LinkedIn with pre-written text: "I scored 7/10 on Greenwash or Not? Can you beat me?")
- CTA: "Want to check a specific claim? Try the Certification Checker"

---

## The Certification Database

### Two Categories of Entries

**1. Real Certifications (Legit or Misleading)**

| Certification | Verdict | Notes |
|--------------|---------|-------|
| Seedling logo (EN 13432) | Legit | Industrial composting certified, but check local council accepts |
| OK Compost HOME | Legit | Breaks down in home compost bins |
| OK Compost INDUSTRIAL | Legit | Requires industrial facilities |
| FSC logo | Partial | Means sustainable forestry, NOT compostable - paper could still have plastic lining |
| "Recyclable" symbol | Partial | Depends on local facilities and contamination |
| PEFC logo | Partial | Similar to FSC - about sourcing, not end-of-life |

**2. Marketing Claims (Usually Greenwash)**

| Claim | Verdict | Notes |
|-------|---------|-------|
| "Biodegradable" | Greenwash | No legal definition, no timeframe required |
| "Eco-friendly" | Greenwash | Meaningless - no standard |
| "Plant-based" | Greenwash | Source material does not equal compostability |
| "Natural" | Greenwash | Unregulated term |
| "Made from recycled materials" | Partial | Good, but doesn't mean recyclable again |
| "Oxo-degradable" | Greenwash | Banned in EU - breaks into microplastics |

### Scope for Launch

- **15-20 real certifications** (logos with images)
- **15-20 common marketing claims** (text-based)
- **Each entry needs:** verdict, one-line truth, "but..." twist, source/reference

### Research Sources

- TUV Austria (OK Compost certification body)
- European Bioplastics
- WRAP UK guidance
- UK Government packaging regulations
- Trading Standards greenwashing cases

---

## Data Collection & The Citable Report

### What Data We Collect

Every game play generates anonymous data:

- **Per card:** Which claim, what user swiped, correct or not
- **Per session:** Final score, time spent, share button clicked (y/n)
- **Aggregate:** Most-missed claims, easiest to spot, average score

No personal data needed. No cookies consent complexity.

### The UK Greenwash Report

This is the linkable asset - a published report with findings journalists can cite.

**Phase 1: Launch Report (Day 1)**

Based on Afida's own research, before any player data:

> "Afida analysed 40 common packaging claims and certifications. Key findings:
> - Only 8 of 40 claims (20%) indicate genuinely compostable packaging
> - 'Biodegradable' appears on 67% of non-compostable packaging we surveyed
> - 15 claims have no legal definition or regulatory oversight"

This gives journalists something to quote immediately.

**Phase 2: Player Data Report (After 1,000+ plays)**

> "New data from 5,000 Greenwash or Not? players reveals:
> - 78% believed 'biodegradable' meant compostable
> - The Seedling logo was correctly identified by only 34% of players
> - Average score: 5.2/10 - most consumers can't spot greenwashing"

**Update Cadence**

Refresh the report quarterly with new player data. Each update is a new PR hook: "Q2 2025: Are UK consumers getting better at spotting greenwashing?"

### Making It Citable

- Dedicated `/greenwash-or-not/report` page with key stats, methodology, downloadable PDF
- Pre-written press release template
- Embeddable stats widgets ("Add our greenwashing stat to your article")
- Clear "Source: Greenwash or Not? by Afida" attribution on all graphics

---

## Technical Architecture

### Frontend

**Stack:** Stimulus controller + Turbo Frames (consistent with existing Afida codebase)

**Key components:**
- `swipe_game_controller.js` - Handles touch/mouse swipe gestures, card animations
- Card stack UI - Current card + next card preview for smooth transitions
- Reveal modal - Flip animation showing verdict and explanation
- Score tracker - Progress bar and running score

**Pages:**
- `/greenwash-or-not` - Landing page + game
- `/greenwash-or-not/checker` - Searchable certification database
- `/greenwash-or-not/report` - The citable UK Greenwash Report

### Backend

**Data model:**

```ruby
# The core database of claims
class Certification < ApplicationRecord
  # name: string ("Seedling logo", "Biodegradable")
  # claim_type: enum (certification, marketing_claim)
  # verdict: enum (legit, partial, greenwash)
  # truth: text (one-sentence explanation)
  # but_twist: text (the surprising reveal)
  # packaging_context: string ("coffee cup", "takeaway box")
  # source_url: string (for credibility)
  # active: boolean

  has_one_attached :image # for certification logos

  enum :claim_type, { certification: 0, marketing_claim: 1 }
  enum :verdict, { legit: 0, partial: 1, greenwash: 2 }
end

# Anonymous game analytics
class GamePlay < ApplicationRecord
  # session_id: string (anonymous UUID)
  # certification_id: references
  # user_answer: enum (legit, greenwash)
  # correct: boolean
  # played_at: datetime

  belongs_to :certification

  enum :user_answer, { legit: 0, greenwash: 1 }
end

# Aggregate session data
class GameSession < ApplicationRecord
  # session_id: string (anonymous UUID)
  # score: integer
  # total_cards: integer
  # completed_at: datetime
  # shared: boolean
end
```

**No user accounts.** Session-based tracking only.

### Stimulus Controller Structure

```javascript
// app/frontend/javascript/controllers/swipe_game_controller.js
// - Manages card deck state
// - Handles swipe gestures (touch + mouse)
// - Animates card transitions
// - Triggers reveal modal
// - Tracks score
// - Posts answers to backend for analytics
```

---

## Launch & Link-Building Strategy

### Pre-Launch (Week -1)

**Build the press list:**
- UK sustainability journalists (Guardian Environment, BBC Future, Edie.net)
- Hospitality trade press (The Caterer, BigHospitality, MCA)
- Marketing/business press (for the greenwashing angle - Marketing Week, The Drum)
- Sustainability bloggers and LinkedIn influencers

**Prepare assets:**
- Press release with key stats from the launch report
- High-res images of the game UI
- Embeddable stat graphics
- Founder quote ready

### Launch Week

**Day 1: Soft launch**
- Publish tool, share with Afida's existing customers and email list
- Gather initial plays to catch bugs and validate flow

**Day 3: Press outreach**
- Send personalised emails to 20-30 journalists
- Hook: "New tool reveals 80% of 'eco' packaging claims are misleading"
- Offer exclusive early data or founder interview

**Day 3-7: Social amplification**
- LinkedIn posts from Afida account and founder
- Tag sustainability accounts and journalists who cover greenwashing
- Encourage team and customers to share their scores

### Ongoing Link-Building

**Reactive PR:**
- Monitor news for greenwashing stories (Google Alerts: "greenwashing UK", "packaging sustainability")
- When relevant story breaks, pitch Afida as expert source with data from the tool

**Content partnerships:**
- Offer the game as embeddable widget for sustainability blogs
- Guest posts analysing specific greenwashing cases using the tool's framework

**Quarterly report updates:**
- Each data refresh is a new PR hook
- "Q2 data shows consumers still fooled by 'biodegradable' claims"

### Success Metrics

| Metric | 3-month target |
|--------|----------------|
| Game plays | 5,000+ |
| Referring domains (backlinks) | 25+ |
| Press mentions | 5+ |
| Checker tool visits | 500+ |

---

## Open Questions

1. **Branding:** Should the tool have its own visual identity, or fully match Afida's brand?
2. **Certification research:** Who will research and write the "but..." twists for each claim?
3. **Share images:** Do we want dynamically generated score cards for social sharing?
4. **Mobile app:** Is a standalone app worth considering later, or web-only?

---

## Next Steps

1. Research and document 30-40 certifications/claims with verdicts and explanations
2. Design the swipe UI (wireframes/mockups)
3. Build database models and seed data
4. Implement Stimulus controller for swipe mechanics
5. Build the checker/search interface
6. Create the report page with embeddable stats
7. Prepare launch assets (press release, social graphics)
8. Soft launch and iterate
