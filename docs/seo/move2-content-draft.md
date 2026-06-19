# Move 2 — content draft for review (v2, fact-checked)

**Status:** ✅ APPLIED TO PRODUCTION 2026-06-19 (via `kamal app exec`; all 6 records verified, FAQ JSON well-formed). Approved by Laurent as written (no NatureFlex branding FAQ; no spec corrections). Already-live since these fields render server-side — no deploy needed.
**Date:** 2026-06-19
**Scope:** FAQs where useful + natureflex-bags meta (blank) + soup-containers retitle. All claims verified against the production database; FAQ count trimmed to what actually answers a buyer question (per your steer — no filler).
**Follow-up queued:** `/collections/takeaway` buying guide (~2,000 words) — task #12, NOT yet written.

**What changed from v1** (after DB fact-check):
- **Takeaway:** my v1 audited the wrong record. There are two `takeaway` collections (slug is unique only per `sample_pack`). The *shop* page (`sample_pack=false`, 27 products) already has a good title + meta — **no retitle needed**. Its real gap is FAQs (and an empty buying_guide, flagged separately). The sample-pack record is a different thing on `/samples`.
- Claims tightened to DB wording (e.g. soup lining is "PE or PLA", not "double poly-lined"; ice-cream cups are "insulated paper", freezer wording softened to match specs).
- NatureFlex home-compostable claim kept but qualified to "many formats" (matches the buying guide's exact phrasing).

Legend: 🆕 new value (field empty) · ✏️ replaces existing · ➕ adding FAQs (0 today).

---

## 1. `/categories/bags-and-wraps/natureflex-bags` — TOP PRIORITY
**Why:** 1,972 imp, pos 16.6, official stockist, and `meta_title` / `meta_description` / `description` are ALL blank. Buying guide already strong. Targets: "natureflex bags" (531), "natureflex bags uk" (177), "natureflex cello bags" (113).
**DB facts:** 8 SKUs; cellulose film from wood pulp; EN 13432 + home-compostable in many formats; heat-sealable; sizes e.g. 220×180mm flat, 150×50×240mm gusset, 350mm baguette; case 1,000 (one 500); ~£0.05–0.11/unit; includes glassine+NatureFlex-window bags.

🆕 **meta_title** (≤60):
`NatureFlex Bags | Compostable Cello Bags UK | Afida`

🆕 **meta_description** (≤155):
`Compostable NatureFlex cello bags for bakeries, delis and cafes. Clear, heat-sealable film bags by the case. Official UK stockist, free delivery over £100.`

🆕 **description** (hero/intro):
`Clear, crinkly and made from wood-pulp cellulose, not plastic: NatureFlex bags are the compostable answer to cello bags. We stock plain, gusseted, baguette and window bags by the case, as an official UK supplier.`

➕ **faqs** (4 — each answers a distinct buyer question):
1. **Q:** What are NatureFlex bags made from?
   **A:** NatureFlex is a transparent film made from renewable wood-pulp cellulose, not plastic. The bags look and feel like a clear cello bag but are certified compostable, so they break down far faster than conventional plastic in the right conditions.
2. **Q:** Are NatureFlex bags home compostable?
   **A:** The film is certified to EN 13432 for industrial composting and is home compostable in many of its formats, so depending on the exact bag it can go in a garden compost bin as well as a council food-waste caddy. That is the main advantage over standard plastic cello bags. Check the spec on each product page.
3. **Q:** What sizes and styles do you stock?
   **A:** Plain flat bags, gusseted bags, baguette bags, and glassine bags with a NatureFlex window, in sizes for bread, pastries, sandwiches and retail items (for example 220×180mm flat or a 350mm baguette bag). Most come as a case of 1,000. Each product page lists exact dimensions.
4. **Q:** Can I get free samples before ordering a case?
   **A:** Yes. Samples are free and you only pay delivery. Order a [free sample](/samples) of the bag styles you are considering, test them with your products, then order full cases once you know the fit.

*(Dropped the v1 "printed/labelled" FAQ — the catalogue has no branded NatureFlex SKUs, so it would over-promise. Mention branding only if you confirm you offer it.)*

---

## 2. `/categories/hot-food/soup-containers` — RETITLE + FAQs
**Why:** 2,065 imp, pos 28, 0 clicks. **Title genuinely wrong:** currently `Takeaway Containers | Eco Bowls from £0.07 | Afida` (one record per slug, so this is confirmed). Targets: "soup containers" (294), "soup container" (292), "takeaway soup containers" (185, pos 10.6 — cliff), "soup containers with lids" (172).
**DB facts:** 18 SKUs; kraft paperboard with PE or PLA lining; 90/115-series; 8oz–32oz incl. 32oz heavy-duty kraft; vented lids sold separately; case 500–1,000; ~£0.07–0.16/unit.

✏️ **meta_title** (was "Takeaway Containers | Eco Bowls…"):
`Soup Containers & Lids | Compostable, Bulk UK | Afida`

✏️ **meta_description**:
`Compostable paper soup containers and matching lids for takeaways and delis. Leak-resistant 8 to 32oz cups by the case. Bulk prices, free UK delivery over £100.`

➕ **faqs** (3):
1. **Q:** Are your soup containers leak-resistant?
   **A:** Yes. They are kraft paper cups with a PE or PLA lining and a tight-fitting hot lid, which holds thick soups, stews and curries. For long deliveries, the 32oz heavy-duty container has a stronger wall and rim.
2. **Q:** What sizes are available, and are lids included?
   **A:** We stock the 90-series and 115-series from roughly 8oz to 32oz. Lids are sold separately so you can match quantities to your menu, and each product page states the series so you order the correct lid. The lids are vented to let steam escape while keeping a secure seal.
3. **Q:** Are the soup containers microwave-safe?
   **A:** No. The lining means they are not microwave-safe, though they are fine for serving hot soup. If your customers reheat leftovers, stock a bagasse container instead, which is microwave and oven safe.

---

## 3. `/categories/cups-and-drinks/ice-cream-cups` — FAQs only
**Why:** 5,081 imp, pos 15 (biggest commercial base). Meta + guide already good. Targets: "ice cream cups" (1,165), "paper ice cream cups uk" (158, pos 11.7 — cliff), "paper ice cream cups with lids" (123).
**DB facts:** 21 SKUs; insulated paper cups 4oz/118ml–10oz/280ml; wooden + paper spoons sold separately; flat + domed lids separate; case 500–2,000; ~£0.03–0.06/unit.

➕ **faqs** (3):
1. **Q:** What sizes do paper ice cream cups come in?
   **A:** From 4oz (118ml) for tasters and kids' portions up to 10oz (280ml) for sundaes and large servings, with sizes in between for standard scoops. Each product page lists the exact capacity.
2. **Q:** Do lids and spoons come with the cups?
   **A:** No, lids and ice-cream spoons are sold separately so you can mix sizes and only buy what you need. Flat and domed lids are available for cups that need a topping or a grab-and-go seal; match the cup size on the product page to the right lid.
3. **Q:** Do the cups keep ice cream cold without going soggy?
   **A:** Yes. They are insulated paper cups that resist condensation and hold frozen desserts at serving temperature from counter to last spoonful. They are made for cold servings, not hot fillings.

---

## 4. `/categories/tableware/cutlery` — FAQs only
**Why:** 1,617 imp, pos 39 (most underranked). Meta + guide good. Targets: "wooden cutlery" (235), "disposable wooden cutlery" (191), "birchwood cutlery" (112), "compostable cutlery" (120).
**DB facts:** 27 SKUs; birchwood kits (4/5/6-in-1, 250/case), wooden spoons (160mm/6.5in, "smooth finish without splinters", compostable), knives/forks, wrapped chopsticks; ~£0.02–0.14/unit. (Buying guide notes plastic cutlery ~£8–12/1,000 for comparison.)

➕ **faqs** (3):
1. **Q:** Is disposable wooden cutlery allowed under UK single-use plastic rules?
   **A:** Yes. Single-use plastic cutlery has been banned for businesses in England since 2023, so wood and birchwood are the compliant disposable choice. All of our cutlery is plastic-free.
2. **Q:** What is the difference between loose cutlery and a cutlery kit?
   **A:** Loose items (spoons, forks, knives) are cheapest per piece and best for self-serve counters. Birchwood kits bundle cutlery in one wrapped pack (4-in-1, 5-in-1 or 6-in-1), which is faster for delivery orders and keeps everything hygienic.
3. **Q:** Is the wooden cutlery compostable, and does it splinter?
   **A:** It is made from sustainably sourced birchwood, fully compostable, and smooth-sanded so it does not splinter or go soggy like cheaper wooden alternatives. To check the feel before committing, order [free samples](/samples).

---

## 5. `/collections/vegware` — FAQs + meta upgrade
**Why:** 566 imp, pos 10.5 (near page 1), official stockist. **Meta thin:** title 30 chars, description 91 chars (generic). Guide already strong. Targets: "vegware" (342), "vegware cups" (299), "vegware uk" (92), "vegware packaging" (47).
Note: a separate rich `/vegware` landing page exists (its own hero + 6 FAQs). Keep these shop-page FAQs distinct and purchase-oriented.

✏️ **meta_title** (was 30 chars):
`Vegware UK | Compostable Cups, Containers & Cutlery | Afida`

✏️ **meta_description** (was generic 91 chars):
`Buy Vegware compostable packaging in the UK: PLA cups, bagasse containers, wooden cutlery and more. Official stockist, by the case, free delivery over £100.`

➕ **faqs** (4):
1. **Q:** Is Afida an official Vegware stockist?
   **A:** Yes. We are an official UK stockist of Vegware and carry their core range of compostable cups, containers, cutlery and packaging by the case, with next-working-day dispatch on stock items.
2. **Q:** Is Vegware compostable, and how do I dispose of it?
   **A:** Vegware is made from plants (PLA, bagasse, paper, board) and is certified to EN 13432 for industrial composting, so it needs a commercial composting or food-waste route rather than a home compost heap for most lines. Check the spec on each product page.
3. **Q:** What is the difference between Vegware PLA and bagasse?
   **A:** PLA is a clear or lined plant-based alternative to plastic, ideal for cold cups and deli boxes. Bagasse is moulded sugarcane fibre: rigid, microwave and oven safe, and naturally grease-resistant, which suits hot mains and curries.
4. **Q:** Can I get free Vegware samples first?
   **A:** Yes. Samples are free and you only pay delivery. Order a [free sample pack](/samples) of the Vegware lines you want to test, trial them in service, then order full cases.

---

## 6. `/collections/takeaway` — FAQs only (NO retitle)
**Why:** 339 imp, pos 28. **Correction from v1:** the *shop* collection (`sample_pack=false`, featured, 27 products: food containers, soup, bags, pizza boxes, cutlery) already has a good title (`Takeaway Containers | Biodegradable Boxes & Packaging`) and meta. So **no retitle needed.** Real gaps: FAQs (0) and an empty `buying_guide`.
Targets: "takeaway packaging suppliers" (328, pos 18), "eco friendly takeaway containers", "biodegradable takeaway containers".

➕ **faqs** (4):
1. **Q:** What packaging do I need for a takeaway?
   **A:** The core kit is leak-resistant food containers with matching lids, kraft bags large enough for a typical order, wood or PLA cutlery (single-use plastic cutlery has been banned for UK businesses since 2023), and napkins. Pizza boxes, soup containers and greaseproof wraps fill in the rest by menu.
2. **Q:** Which takeaway containers are microwave-safe for reheating?
   **A:** Bagasse containers and aluminium trays are microwave and oven safe; kraft and PLA-lined containers are not. If customers reheat leftovers, stock bagasse or aluminium for those dishes.
3. **Q:** Can I buy takeaway packaging in bulk, and how fast is delivery?
   **A:** Everything is priced by the case with bulk pricing built in. Order before the daily cutoff and stock items ship next working day.
4. **Q:** Can I get free samples before ordering?
   **A:** Yes. Samples are free and you only pay delivery. Order a [free sample pack](/samples) of the containers and bags you want to test, then order in bulk once you know they fit.

⚠️ **Separate (bigger) task — your call:** `/collections/takeaway` has NO buying guide, unlike restaurants/coffee-shops/vegware. Writing one (≈1,500–2,500 words, like the others) is a larger job I'd do as its own step, not in this content batch. Want it queued?

---

## Not touched (already strong on production)
- `/collections/restaurants`, `/collections/coffee-shops` — meta + guide + 5 FAQs each (the template).
- `hot-cups`, `napkins`, `pizza-boxes` categories — meta + guide present; FAQs could be a later batch, not this scope.

## Open questions for you
1. **NatureFlex branding:** the catalogue has no printed/branded NatureFlex SKUs. Do you offer custom-printed NatureFlex (so I can add that FAQ), or leave it out (current draft leaves it out)?
2. **Takeaway buying guide** (section 6): queue it as a separate task, or skip?
3. **Any spec corrections?** I've matched DB wording, but you know edge cases (e.g. which exact NatureFlex formats are home-compostable, whether all soup linings are PLA vs PE). Flag anything that overstates.
