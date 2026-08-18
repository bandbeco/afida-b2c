#!/usr/bin/env python3
"""Cluster the content-gap keywords into page-sized targets and buckets.

Buckets:
  1 = page exists in the live catalog taxonomy, retarget/upgrade it
  2 = products exist but no dedicated rankable page, build one
  3 = products not stocked, range decision for Afida leadership
  skip = off-brand (conventional plastic partyware, janitorial, generics)

Bucket/target assignments were made against the 2026-08-19 production
catalog snapshot (prod-catalog-snapshot.txt), not guessed.
"""
import csv
import re

# (cluster, bucket, target, regex) - first match wins, order matters.
RULES = [
    # --- skips: off-brand conventional plastic / non-range / junk generics
    ("skip-plastic-partyware", "skip", "", r"plastic|polycarbonate|polystyrene|cling|solo cup|red cup|red party|party cup|jager|margarita|martini|gin gl|wine gl|wine\b|champagne|prosecco|coupe|flute|tumbler|beer cup|port glass|slim jim|175ml glass|half pint|pint glass|pint cup|disposable glasses|party glasses|red solo|cocktail glass"),
    ("skip-non-range", "skip", "", r"\bmop\b|wipe|kentucky|banquet|tablecloth|table cloth|table cover|placemat|spice jar|oven bag|kitchen foil|kitchen paper|foil paper|aluminium foil$|pudding basin|sabert|biopak|restaurant name|cupcake decorating|cake last|freeze cupcake|hot drinks cool|mailing|paper straws uk|drinking straws$|bendy|coca cola|hot chocolate|water cup|prep bowl|kebab|sushi|oven|juice bottle|50ml|500ml|hot dog|kids meal|food boat|polythene|blue wipes|flan dish|salt and pepper"),
    ("skip-generic-size", "skip", "", r"^\d+ ?oz( cup| cups| coffee cup| ripple cups| plastic cups)?$|^9 inch pizza$|^microwavable$|^4oz$|^500ml$"),
    # --- bucket 3: range gaps (verified absent from catalog)
    ("cake-boxes", "3", "(new range) cake & cupcake boxes", r"cake|cupcake|cookie|bakery packaging"),
    ("chicken-boxes", "3", "(new range) chicken boxes & buckets", r"chicken"),
    # --- custom / branded print lane (before generic matches)
    ("custom-print", "2", "/categories/branded-products (expand + per-product landing pages)", r"custom|personalised|branded|logo|printed paper bag|printed greaseproof|design service|food packaging design|packaging designer|sample packaging|branding"),
    # --- bucket 2: stocked, no dedicated page
    ("burger-boxes", "2", "(new page) burger boxes", r"burger"),
    ("fish-chip-boxes", "2", "(new page) fish & chip boxes + chip trays", r"fish and chip|fish & chip|chip box|chip tray|chip boxes|chips box"),
    ("noodle-boxes", "2", "(new page) noodle / chinese takeaway boxes (kraft takeaway boxes)", r"noodle|chinese takeaway"),
    ("microwavable", "2", "(new page) microwavable containers", r"microwav"),
    ("platters-catering", "2", "(new page) platter boxes & catering trays", r"platter|buffet|catering tray|catering box|catering container|sandwich tray"),
    ("smoothie-cups", "2", "(new page) smoothie & milkshake cups", r"smoothie|milkshake|boba|slush|iced coffee"),
    ("ice-cream-tubs", "2", "(new page) ice cream tubs & pots (split from ice-cream-cups)", r"ice cream tub|ice cream pot|ice cream box|gelato"),
    ("dessert-cups", "2", "(new page) dessert cups & pots", r"dessert"),
    ("cup-carriers", "2", "(new page) cup & drink carriers", r"drink carrier|cup carrier"),
    ("wooden-spoons", "2", "product page exists; feature on cutlery page", r"wooden spoon"),
    ("food-trays", "2", "(new page) food trays (microflute + folded board)", r"food tray|disposable trays|kraft tray|baguette tray"),
    # --- bucket 1: category page exists, retarget/upgrade
    ("paper-plates", "1", "/categories/tableware/plates-and-bowls (split: plates)", r"paper plates|disposable plates|bagasse plates|palm leaf|white paper plates|^plates?$"),
    ("bowls", "1", "/categories/food-containers/bowls-and-lids", r"bowl"),
    ("pizza-boxes", "1", "/categories/food-containers/pizza-boxes", r"pizza"),
    ("napkins", "1", "/categories/tableware/napkins", r"napkin|serviette"),
    ("greaseproof", "1", "/categories/bags-and-wraps/greaseproof-and-wraps", r"greaseproof|grease paper"),
    ("paper-bags", "1", "/categories/bags-and-wraps/bags", r"paper bag|grab bag|sos bag|paper carrier|takeaway bags|food bags|sweet bag|brown paper|white paper bags|black paper|kraft paper bag|paper party|paper food|paper takeaway|sandwich bag"),
    ("soup-containers", "1", "/categories/food-containers/soup-containers", r"soup"),
    ("coffee-cups", "1", "/categories/cups-and-accessories/hot-cups", r"coffee|hot drink|hot cup|insulated|ripple cup|takeaway cup|take away coffee|tea cup|single wall|disposable cup|paper cups|drink cup|compostable cup|biodegradable cup|recyclable cup|cups with lids|takeaway coffee"),
    ("cold-cups", "1", "/categories/cups-and-accessories/cold-cups-and-lids", r"cold cup|clear plastic cup|shot glass"),
    ("cutlery", "1", "/categories/tableware/cutlery (retarget: wooden cutlery)", r"cutlery|wooden fork|wooden knife|spoon|fork|knife|chopstick|stirrer"),
    ("straws", "1", "/categories/cups-and-accessories/straws", r"straw"),
    ("foil-trays", "1", "/categories/food-containers/aluminium-containers (retarget: foil trays)", r"foil|aluminium"),
    ("deli-pots", "1", "/categories/cold-food-and-salads/deli-containers", r"deli"),
    ("salad-boxes", "1", "/categories/cold-food-and-salads/salad-boxes", r"salad"),
    ("sandwich-wrap-boxes", "1", "/categories/cold-food-and-salads/sandwich-and-wrap-boxes", r"sandwich|tortilla|wrap|baguette"),
    ("portion-sauce-pots", "1", "/categories/food-containers/portion-pots-and-lids (retarget: + sauce pots)", r"portion|sauce pot|dip pot|pots with lids"),
    ("takeaway-food-boxes", "1", "/categories/food-containers/takeaway-boxes", r"food box|takeaway box|take away box|takeaway food box|kraft box|clamshell|takeaway suppl|lunch box|paper boxes for food|cardboard food"),
    ("takeaway-containers", "1", "/categories/food-containers (+ food-containers-and-lids)", r"takeaway container|take away container|food container|takeaway food container|take away food container|recyclable food container|compostable food container|food storage"),
    ("bagasse", "1", "/categories/food-containers/bagasse-containers", r"bagasse"),
    ("lids", "1", "/categories/cups-and-accessories/hot-cup-lids", r"\blids?\b"),
    ("gloves-supplies", "1", "/categories/supplies-and-essentials/gloves-and-cleaning", r"glove"),
    ("ice-cream-cups", "1", "/categories/cups-and-accessories/ice-cream-cups", r"ice cream"),
    ("eco-packaging-generic", "1", "homepage / /shop (site-level head terms)", r"eco|biodegradable|plant based|recyclable|compostable|sustainab|food packaging|takeaway packaging|hot food packaging|food delivery packaging|catering disposables|takeaway supplies|kraft|packaging"),
]

rows = list(csv.DictReader(open("content-gap-gb-easy.csv")))
out = []
for r in rows:
    kw = r["keyword"].strip().lower()
    cluster, bucket, target = "UNCLUSTERED", "?", ""
    for c, b, t, rx in RULES:
        if re.search(rx, kw):
            cluster, bucket, target = c, b, t
            break
    out.append({**r, "cluster": cluster, "bucket": bucket, "target": target})

with open("cluster-map-gb.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(out[0].keys()))
    w.writeheader()
    w.writerows(out)

# summary
from collections import defaultdict
agg = defaultdict(lambda: {"vol": 0, "n": 0, "bucket": "", "target": "", "top": []})
for r in out:
    a = agg[r["cluster"]]
    a["vol"] += int(r["volume"]); a["n"] += 1
    a["bucket"], a["target"] = r["bucket"], r["target"]
    if len(a["top"]) < 4:
        a["top"].append(f'{r["keyword"]}({r["volume"]})')
for c, a in sorted(agg.items(), key=lambda x: -x[1]["vol"]):
    print(f'{a["bucket"]:>4} | {c:<24} | {a["vol"]:>6} vol | {a["n"]:>3} kws | {", ".join(a["top"])} | {a["target"]}')
print("\nUNCLUSTERED:")
for r in out:
    if r["cluster"] == "UNCLUSTERED":
        print(" ", r["keyword"], r["volume"])
