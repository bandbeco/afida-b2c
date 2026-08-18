#!/usr/bin/env python3
"""Compute link-intersect-attainable.csv: domains linking to >=2 of the 3
competitors (takeawaypackaging.co.uk, cupsdirect.co.uk, greenpak.supplies)
but not to afida.com.
"""
import csv
import os

DIR = os.path.dirname(os.path.abspath(__file__))

COMPETITORS = ["takeawaypackaging.co.uk", "cupsdirect.co.uk", "greenpak.supplies"]


def load_domains(path):
    domains = {}
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            d = row["domain"].strip().lower()
            dr = float(row["domain_rating"]) if row["domain_rating"] else 0.0
            domains[d] = dr
    return domains


def main():
    afida_domains = set(load_domains(os.path.join(DIR, "afida.com-refdomains.csv")).keys())

    comp_domains = {}
    for comp in COMPETITORS:
        comp_domains[comp] = load_domains(os.path.join(DIR, f"{comp}-refdomains.csv"))

    all_domains = set()
    for d in comp_domains.values():
        all_domains |= set(d.keys())

    rows = []
    for domain in all_domains:
        if domain in afida_domains:
            continue
        linking = [comp for comp in COMPETITORS if domain in comp_domains[comp]]
        if len(linking) < 2:
            continue
        dr = max(comp_domains[comp][domain] for comp in linking)
        rows.append(
            {
                "domain": domain,
                "domain_rating": dr,
                "links_to": ";".join(linking),
            }
        )

    rows.sort(key=lambda r: r["domain_rating"], reverse=True)

    out_path = os.path.join(DIR, "link-intersect-attainable.csv")
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["domain", "domain_rating", "links_to"], quoting=csv.QUOTE_MINIMAL)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)

    print(f"link-intersect-attainable.csv: {len(rows)} rows")


if __name__ == "__main__":
    main()
