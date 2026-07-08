---
type: Report
description: Bestselling products by revenue, units and orders for March to June 2026, pulled from the production database on 2026-06-30.
timestamp: 2026-06-30
---

# Bestselling Products — Mar–Jun 2026

**Source:** Production database (`kamal app exec … rails runner`), pulled 2026-06-30.
**Window:** Orders created 2026-03-01 → 2026-06-30.
**Order filter:** status ∈ `paid, processing, shipped, delivered` (excludes pending / cancelled / refunded). Sample line items (`is_sample = true`, £0) excluded.

## Summary

| Metric | Value |
|---|---|
| Valid orders in window | 67 |
| Non-sample line items | 113 |
| Total non-sample revenue | £5,399.64 |
| Distinct products sold | see tables below |

Revenue is `SUM(order_items.line_total)` (pack price × quantity, captured at order time). "Units" is `SUM(quantity)` (packs/units as ordered). "Orders" is the count of distinct orders containing the product.

## Top 10 by revenue

| # | Product | SKU | Revenue | Units | Orders |
|---|---|---|--:|--:|--:|
| 1 | Vegware PLA Bella Pot, 96-Series – 16oz | VEG-DEL-16 | £468.81 | 3 | 2 |
| 2 | Vegware Feel Good Double Wall Hot Cup – 8oz | VEG-CUP-DW-8 | £383.78 | 10 | 3 |
| 3 | Black Bio Fibre Straws – 6 × 200mm | BB-FBRBL-20 | £335.72 | 4 | 4 |
| 4 | Vegware PLA Cold Cup, 96 Series – 9oz | VEG-CC-9-7 | £230.51 | 5 | 4 |
| 5 | Vegware Feel Good Double Wall Hot Cup – 12oz | VEG-CUP-DW-12 | £187.88 | 4 | 4 |
| 6 | 24 × 24cm Black Paper Cocktail Napkins | PCNBL | £172.74 | 6 | 1 |
| 7 | Vegware PLA Dome Lid, Straw Slot (Fits 96 Series) | VEG-CC-DL | £164.85 | 3 | 2 |
| 8 | 2oz Paper Portion Pot Lid | POT-2 | £138.03 | 3 | 2 |
| 9 | Kraft Salad Bowl Lid – 500ml / 1000ml | CNT-500-KR | £135.66 | 3 | 2 |
| 10 | 6 × 200mm Black Paper Straws | BPS20 | £127.20 | 3 | 2 |

## Top 10 by units sold

| # | Product | SKU | Units | Revenue | Orders |
|---|---|---|--:|--:|--:|
| 1 | Vegware PLA Cold Cup, 76 Series – 5oz | VEG-CC-5-2 | 10 | £66.40 | 5 |
| 2 | Vegware Feel Good Double Wall Hot Cup – 8oz | VEG-CUP-DW-8 | 10 | £383.78 | 3 |
| 3 | Vegware PLA Cold Cup, 96 Series – 16oz | VEG-CC-16-4 | 8 | £119.20 | 5 |
| 4 | Vegware 5oz PLA Cold Cup, 76 Series Green Tree | VEG-CC-5-GN | 7 | £45.92 | 2 |
| 5 | Paper Leakproof Pots with Lids | FNC-7 | 6 | £115.20 | 1 |
| 6 | 24 × 24cm Black Paper Cocktail Napkins | PCNBL | 6 | £172.74 | 1 |
| 7 | Vegware PLA Cold Cup, 96 Series – 9oz | VEG-CC-9-7 | 5 | £230.51 | 4 |
| 8 | Black Bio Fibre Straws – 6 × 200mm | BB-FBRBL-20 | 4 | £335.72 | 4 |
| 9 | Vegware Feel Good Double Wall Hot Cup – 12oz | VEG-CUP-DW-12 | 4 | £187.88 | 4 |
| 10 | Vegware PLA Cold Cup, 76 Series – 7oz | VEG-CC-7 | 4 | £32.84 | 2 |

## Top 10 by order frequency (breadth of demand)

| # | Product | SKU | Orders | Revenue | Units |
|---|---|---|--:|--:|--:|
| 1 | Vegware PLA Cold Cup, 76 Series – 5oz | VEG-CC-5-2 | 5 | £66.40 | 10 |
| 2 | Vegware PLA Cold Cup, 96 Series – 16oz | VEG-CC-16-4 | 5 | £119.20 | 8 |
| 3 | Vegware PLA Cold Cup, 96 Series – 9oz | VEG-CC-9-7 | 4 | £230.51 | 5 |
| 4 | Black Bio Fibre Straws – 6 × 200mm | BB-FBRBL-20 | 4 | £335.72 | 4 |
| 5 | Vegware Feel Good Double Wall Hot Cup – 12oz | VEG-CUP-DW-12 | 4 | £187.88 | 4 |
| 6 | Vegware Feel Good Double Wall Hot Cup – 8oz | VEG-CUP-DW-8 | 3 | £383.78 | 10 |
| 7 | Vegware Kraft Flat Bag – 254 × 254mm | VEG-BAG-KR-5 | 3 | £43.32 | 3 |
| 8 | Vegware PLA Bella Pot, 96-Series – 16oz | VEG-DEL-16 | 2 | £468.81 | 3 |
| 9 | Kraft Salad Bowl Lid – 500ml / 1000ml | CNT-500-KR | 2 | £135.66 | 3 |
| 10 | 1000ml Kraft Rectangular Kraft Bowls | 10MLREC | 2 | £120.52 | 3 |

## Notes & caveats

- Small-sample data: 67 orders / £5.4k over 4 months. Rankings are sensitive to single large orders (e.g. VEG-DEL-16 #1 by revenue is just 2 orders), so the three lenses tell different stories.
- **Vegware cold cups** are the broadest demand driver (top of the order-frequency and units lists) but each order is low-value. **Bella Pots** and **double-wall hot cups** drive revenue.
- "Units" mixes packs and units; a pack of straws and a pack of cups both count as 1 unit per pack ordered. Treat units as relative, not absolute pieces.
- Window is by `order.created_at`. Branded/configured orders are included; samples are excluded.
