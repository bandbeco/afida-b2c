#!/usr/bin/env python3
"""Compute content-gap tables from the Ahrefs organic-keyword CSVs pulled 2026-08-18.

Reads:
  afida.com-keywords-gb.csv
  <competitor>-keywords-gb.csv  (6 files)

Writes:
  content-gap-gb.csv
  content-gap-gb-easy.csv
"""
import csv
import os

DIR = os.path.dirname(os.path.abspath(__file__))

COMPETITORS = [
    "takeawaypackaging.co.uk",
    "cupsdirect.co.uk",
    "enviropack.org.uk",
    "eventsupplies.co.uk",
    "greenpak.supplies",
    "cater4you.co.uk",
]

# Substrings (lowercase) that mark a keyword as branded to a competitor; exclude from gap output.
BRAND_TERMS = [
    "takeaway packaging co",
    "cupsdirect",
    "cups direct",
    "enviropack",
    "cater4you",
    "cater 4 you",
    "cater for you",
    "greenpak",
    "green pak",
    "event supplies",
    "eventsupplies",
]


def load_keywords(path):
    rows = []
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            row["best_position"] = int(row["best_position"])
            row["volume"] = int(row["volume"])
            kd = row["keyword_difficulty"]
            row["keyword_difficulty"] = int(kd) if kd not in ("", None) else 0
            rows.append(row)
    return rows


def is_branded(keyword_lower):
    return any(term in keyword_lower for term in BRAND_TERMS)


def main():
    afida_path = os.path.join(DIR, "afida.com-keywords-gb.csv")
    afida_rows = load_keywords(afida_path)
    afida_keywords = {r["keyword"].strip().lower() for r in afida_rows}

    # keyword_lower -> dict(keyword, volume, keyword_difficulty, competitors: {name: (position, url)})
    gap = {}

    for comp in COMPETITORS:
        path = os.path.join(DIR, f"{comp}-keywords-gb.csv")
        rows = load_keywords(path)
        for r in rows:
            kw = r["keyword"].strip()
            kw_lower = kw.lower()
            if r["best_position"] > 20:
                continue
            if kw_lower in afida_keywords:
                continue
            if is_branded(kw_lower):
                continue
            entry = gap.setdefault(
                kw_lower,
                {
                    "keyword": kw,
                    "volume": r["volume"],
                    "keyword_difficulty": r["keyword_difficulty"],
                    "competitors": {},
                },
            )
            # Keep the max volume / (first-seen) difficulty; values are consistent per keyword generally.
            entry["volume"] = max(entry["volume"], r["volume"])
            entry["competitors"][comp] = (r["best_position"], r["best_position_url"])

    gap_rows = []
    for kw_lower, entry in gap.items():
        competitors = entry["competitors"]
        n_competitors = len(competitors)
        best_comp = min(competitors.items(), key=lambda kv: kv[1][0])
        best_comp_name, (best_comp_pos, best_comp_url) = best_comp
        gap_rows.append(
            {
                "keyword": entry["keyword"],
                "volume": entry["volume"],
                "keyword_difficulty": entry["keyword_difficulty"],
                "n_competitors_ranking": n_competitors,
                "best_competitor": best_comp_name,
                "best_competitor_position": best_comp_pos,
                "best_competitor_url": best_comp_url,
            }
        )

    gap_rows.sort(key=lambda r: r["volume"], reverse=True)

    fieldnames = [
        "keyword",
        "volume",
        "keyword_difficulty",
        "n_competitors_ranking",
        "best_competitor",
        "best_competitor_position",
        "best_competitor_url",
    ]

    out_path = os.path.join(DIR, "content-gap-gb.csv")
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, quoting=csv.QUOTE_MINIMAL)
        writer.writeheader()
        for row in gap_rows:
            writer.writerow(row)

    easy_rows = [
        r for r in gap_rows if r["keyword_difficulty"] <= 10 and r["volume"] >= 50
    ]
    easy_path = os.path.join(DIR, "content-gap-gb-easy.csv")
    with open(easy_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, quoting=csv.QUOTE_MINIMAL)
        writer.writeheader()
        for row in easy_rows:
            writer.writerow(row)

    print(f"content-gap-gb.csv: {len(gap_rows)} rows")
    print(f"content-gap-gb-easy.csv: {len(easy_rows)} rows")


if __name__ == "__main__":
    main()
