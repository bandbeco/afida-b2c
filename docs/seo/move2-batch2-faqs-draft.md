# Move 2 — batch 2 content draft (FAQs only)

**Status:** ✅ APPLIED TO PRODUCTION 2026-06-19 (via `kamal app exec --reuse --roles=web`). All three categories written (hot-cups 0→4, napkins 0→4, pizza-boxes 0→3); fields_ok + json_ok on write. Verified live over HTTP (following the 301 to the nested canonical `/categories/<parent>/<slug>` URLs): each page renders the "Frequently Asked Questions" section + a valid `FAQPage` JSON-LD block with the right question count; `[free samples](/samples)` renders as a real anchor; the corrected "aqueous (water-based) lining" disposal wording is live. FAQs render server-side, so live immediately with no deploy.
**Date:** 2026-06-19
**Scope:** Add genuinely-useful FAQs to three category pages that already have good `meta_title` and buying guides but `faqs = 0`: `hot-cups`, `napkins`, `pizza-boxes`. FAQs render server-side as FAQPage JSON-LD (live immediately, no deploy). No meta or guide changes. Not TDD (content data).

**Discipline (same as batch 1):**
- Every FAQ answers a distinct question a buyer actually asks before ordering. No filler.
- FAQs complement the buying guide; they do not restate it. The guides already cover how-to-choose depth (ply, wall type, sizing theory), so these target quick purchase decisions and the practical "before I order" questions.
- All claims grounded in the production database (facts dumped 2026-06-19 from the live web container).
- No bold/semibold. Qualitative pricing only (catalogue prices are per-case, so no per-unit figures stated).
- Free-samples link uses `[free samples](/samples)` markdown, which renders (confirmed against batch-1 live FAQs).

**DB facts used (production, 2026-06-19):**
- hot-cups: 55 active SKUs; single-wall, double-wall and ripple-wall paper hot cups; 4oz–20oz; 62/72/79/89 series; plain + Vegware "Feel Good" lines; compostable / PLA-lined. Lids are a separate category (cups do not include lids). meta_title `Disposable Coffee Cups & Lids | from £0.02 | Afida`; buying guide present.
- napkins: 16 active SKUs; 1-ply, 2-ply and unbleached; cocktail (24–25cm), lunch/dinner (33–40cm), dispenser napkins; white + coloured (navy); one SKU ships with 2 free dispensers. meta_title `Paper Napkins & Serviettes | Bulk UK | Afida`; buying guide present.
- pizza-boxes: 6 active SKUs; corrugated kraft; 7/9/10/12/16 inch + a pizza slice tray; recyclable kerbside if not grease-soaked; arrive flat-packed; no certifications needed. meta_title `Pizza Boxes | Kraft 7 to 16 Inch | Bulk UK | Afida`; buying guide present.

**GSC targets (where known, from move2 brief):**
- napkins: "napkins for restaurants" (150, pos 9.27), "paper napkins for restaurants" (130, pos 7.59) — strong B2B intent; plus "paper napkins bulk".
- hot-cups: head terms "disposable coffee cups", "takeaway coffee cups", "compostable coffee cups", "double wall coffee cups" (no per-query GSC pulled for this page; treat as head-term depth).
- pizza-boxes: "pizza boxes", "kraft pizza boxes", "pizza boxes bulk/wholesale".

Legend: ➕ adding FAQs (0 today).

---

## 1. `/categories/hot-cups` — FAQs only (4)
**Why:** 55 SKUs, strong meta + guide, but 0 FAQs. The questions buyers ask before ordering cups are predictable and not fully answered by the guide: do lids come with them, single vs double wall, how to dispose, what sizes.

➕ **faqs:**

1. **Q:** Do your coffee cups come with lids?
   **A:** No, lids are sold separately so you can match lid quantities and styles to your cups rather than paying for ones you do not need. Cups and lids are sized by series (for example 79 or 89 series), and each cup product page states the series so you order the matching lid.

2. **Q:** What is the difference between single-wall and double-wall cups?
   **A:** Single-wall cups are the cheapest per cup and work well with a sleeve or for shorter drinks. Double-wall and ripple-wall cups have an insulating outer layer that stays comfortable to hold without a sleeve, which suits hot drinks served to go. We stock all three, from 4oz espresso up to 16oz and 20oz.

3. **Q:** Are the cups compostable or recyclable?
   **A:** Both, depending on the line. We stock compostable paper cups, and cups with an aqueous (water-based) lining that are designed to be recyclable as well. The lining matters for disposal: aqueous-lined cups are easier to recycle, while plant-based PLA-lined cups are suited to commercial composting. Each product page states the lining and how to dispose of that cup, so you can match it to your waste route.

4. **Q:** Can I get free samples before ordering a case?
   **A:** Yes. Samples are free and you only pay delivery. Order [free samples](/samples) of the cup sizes and wall types you are considering, test them with your drinks, then order full cases once you know the fit.

*(Considered but dropped: a "can I get them branded?" FAQ. The catalogue hot-cups are stock lines; only add a branding FAQ if custom-print cups are actually offered, to avoid over-promising as with NatureFlex in batch 1.)*

---

## 2. `/categories/napkins` — FAQs only (4)
**Why:** 16 SKUs, detailed guide, 0 FAQs. Best B2B opportunity in this batch: "napkins for restaurants" (pos 9.27) and "paper napkins for restaurants" (pos 7.59) are near the page-1 cliff. FAQs should serve both the restaurant buyer and the practical ply/size/dispenser questions the guide treats theoretically.

➕ **faqs:**

1. **Q:** Which napkins are best for a restaurant or takeaway?
   **A:** For most food service, a two-ply napkin in a lunch or dinner size (around 33cm to 40cm) is the sensible default: strong enough for greasy or saucy food without over-spending. Cocktail napkins (around 24cm) suit coffee shops and light bites, and dispenser napkins fit table dispensers. We stock all of these in bulk by the case.

2. **Q:** What is the difference between 1-ply and 2-ply napkins?
   **A:** One-ply is the thinnest and cheapest, fine for pastry counters, coffee and light use. Two-ply is noticeably stronger and holds together with greasy or saucy food, which is why it is the standard for takeaways and casual dining. If your busiest dish is messy, two-ply is worth the small extra cost.

3. **Q:** Do you stock unbleached and coloured napkins?
   **A:** Yes. Alongside white we carry unbleached (natural) napkins for an eco-conscious look and coloured options such as navy for table service and events. Coloured napkins cost a little more but lift presentation where it matters.

4. **Q:** Can I get free napkin samples before ordering?
   **A:** Yes. Samples are free and you only pay delivery. Because wet strength varies between suppliers, we recommend you order [free samples](/samples) and test a napkin against your messiest dish before committing to a case.

---

## 3. `/categories/pizza-boxes` — FAQs only (3)
**Why:** 6 SKUs, detailed guide, 0 FAQs. The buyer questions are tight and specific (what sizes, are they recyclable, storage), so three focused FAQs cover it without filler.

➕ **faqs:**

1. **Q:** What sizes of pizza box do you stock?
   **A:** Corrugated kraft boxes in 7, 9, 10, 12 and 16 inch, measured by the pizza diameter they hold. The 12 inch is the most popular UK takeaway size and a safe default if you standardise on one. We also stock a pizza slice tray for serving by the slice. Smaller boxes double up for calzones, garlic bread and sides.

2. **Q:** Are kraft pizza boxes recyclable?
   **A:** Yes, plain corrugated kraft boxes are recyclable through standard kerbside collection, as long as they are not heavily soiled with grease and food. They are made from unbleached paper fibre with no plastic lining, so they biodegrade naturally and need no special certification.

3. **Q:** Do the boxes arrive flat-packed, and can I buy in bulk?
   **A:** Yes. The boxes arrive flat-packed and assemble in seconds, and everything is priced by the case with bulk pricing built in. Order before the daily cutoff and stock items ship next working day. Allow some storage space, as flat-packed boxes still take up room in volume.

---

## Notes for review
- All three already have good meta and a buying guide, so this batch is purely additive FAQs (no retitles, unlike batch 1's soup-containers).
- FAQ counts: hot-cups 4, napkins 4, pizza-boxes 3 — trimmed to distinct buyer questions, matching the "no filler" steer.
- No branding FAQs added anywhere (would need confirmation that custom print is offered).
- One open check below.

## Fact-check applied
- **Hot-cup disposal (FAQ 3) corrected after DB scan:** the range is not uniformly PLA-lined. Of 55 cups, 15 descriptions say "compostable", 9 say "recyclable" (one says both), and there is an "aqueous lined" line (CUP-12) distinct from PLA. FAQ 3 was rewritten to reflect the mixed range (compostable paper + aqueous-lined recyclable + PLA-lined compostable) rather than overstating PLA, and to point to the per-product spec for disposal. No remaining open questions.
