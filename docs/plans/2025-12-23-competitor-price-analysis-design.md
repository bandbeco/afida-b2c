# Competitor Price Analysis Tool - Design Document

## Overview

A Ruby script for periodic competitor price comparison using Firecrawl. Generates a CSV spreadsheet and markdown report to understand Afida's competitive positioning.

## Goals

1. **Pricing strategy** - Know if Afida is priced competitively
2. **Marketing positioning** - Find areas where Afida beats competitors
3. **Product gap analysis** - See what products competitors offer that Afida doesn't

## Approach

- **Periodic manual runs** (not automated monitoring)
- Run monthly/quarterly when pricing reviews are needed
- Uses Firecrawl API for scraping (estimated 500-750 credits per run)
- Hybrid product matching with manual verification

## Target Competitors

| Competitor | URL | Site Type |
|------------|-----|-----------|
| CupsDirect | cupsdirect.co.uk | Shopify |
| Purple Planet Packaging | purpleplanetpackaging.co.uk | WooCommerce |
| Ambican | ambican.com | WooCommerce |
| Takeaway Packaging | takeawaypackaging.co.uk | Custom |

## Data Flow

```
┌─────────────────┐     ┌──────────────────────────┐
│ Afida Products  │     │ Firecrawl Extract        │
│ (from database) │     │ (competitor product URLs)│
└────────┬────────┘     └────────────┬─────────────┘
         │                           │
         │    ┌──────────────────────┘
         │    │  JSON: {name, price, pack_size, url}
         ▼    ▼
    ┌─────────────────────┐
    │   Matching Engine   │
    └──────────┬──────────┘
               ▼
      CSV + Markdown Report
```

## Extraction Schema

All competitors use the same extraction schema:

```json
{
  "product_name": "string",
  "price": "number",
  "pack_size": "number",
  "size_label": "string (e.g., '12oz', '500ml')",
  "material": "string (e.g., 'kraft', 'bagasse')",
  "url": "string"
}
```

## Product Matching

### Hybrid Approach

Three-layer matching with increasing automation:

1. **Manual overrides (highest priority)** - Verified mappings in `mappings.yml`
2. **Exact match** - Same category + same size label
3. **Fuzzy match** - Same category + similar size

### Category Normalization

| Standard Category | Afida Products | Competitor Variations |
|-------------------|----------------|----------------------|
| `double_wall_cups` | Double Wall Coffee Cups | Double Wall, DW Cups, Insulated Cups |
| `single_wall_cups` | Single Wall Coffee Cups | Paper Cups, Hot Cups, SW Cups |
| `clear_cups` | Clear Plastic Cups | PET Cups, Cold Cups, Smoothie Cups |
| `bagasse_lids` | Compostable Coffee Cup Lids | Bagasse Lids, Fibre Lids |
| `straws` | Biodegradable Straws | Paper Straws, Eco Straws |
| `napkins` | Paper Napkins | Serviettes, Napkins |

### Size Normalization

Convert all sizes to ml for comparison:
- 8oz → 237ml
- 12oz → 355ml
- 16oz → 473ml

### Mappings File Format

```yaml
# Auto-generated matches (review and keep/delete)
pending_review:
  - afida_sku: "12-DWC-K"
    competitor: "cupsdirect"
    competitor_url: "https://cupsdirect.co.uk/products/..."
    match_confidence: 0.85

# Your verified matches
verified:
  - afida_sku: "12-DWC-K"
    competitor: "cupsdirect"
    competitor_url: "https://cupsdirect.co.uk/products/..."
```

## Price Normalization

All prices normalized to **price per 1000 units** for fair comparison across different pack sizes.

## Output Files

### CSV (`tmp/competitor_analysis/comparison_YYYY-MM-DD.csv`)

| Column | Description |
|--------|-------------|
| `afida_product` | Product name |
| `afida_sku` | SKU |
| `afida_size` | Size label (12oz, etc.) |
| `afida_price_per_1000` | Normalized price |
| `cupsdirect_price_per_1000` | Competitor price (blank if no match) |
| `cupsdirect_diff_pct` | % difference (+10% = Afida is 10% more expensive) |
| `purpleplanet_price_per_1000` | ... |
| `purpleplanet_diff_pct` | ... |
| `ambican_price_per_1000` | ... |
| `ambican_diff_pct` | ... |
| `match_quality` | "verified", "auto", or "fuzzy" |

### Markdown Report (`tmp/competitor_analysis/report_YYYY-MM-DD.md`)

```markdown
# Competitor Price Analysis - 2024-01-15

## Summary
- **Products analyzed:** 45
- **Afida cheaper on:** 28 products (62%)
- **Afida more expensive on:** 12 products (27%)
- **No competitor match:** 5 products (11%)

## Where Afida Wins (>10% cheaper)
| Product | Afida | Best Competitor | Savings |
|---------|-------|-----------------|---------|
| Double Wall 12oz Kraft | £77.62 | £82.90 (CupsDirect) | 6.4% |

## Where Afida Loses (>10% more expensive)
| Product | Afida | Best Competitor | Gap |
|---------|-------|-----------------|-----|
| Biodegradable Straws 6x150mm | £90.00 | £78.50 (Ambican) | +14.6% |

## Product Gaps
Products competitors offer that Afida doesn't:
- Ripple wall cups (CupsDirect, Purple Planet)
- Bamboo cutlery (Ambican)

## Recommendations
1. **Quick wins:** Consider price adjustments on [X, Y, Z]
2. **Marketing angles:** Highlight competitive pricing on [A, B, C]
3. **Product gaps:** Evaluate adding [ripple cups] to range
```

## Usage

### Commands

```bash
# Full run (scrape + compare + report)
rails runner lib/competitor_analysis/run.rb

# Skip scraping, use cached data (for tweaking report format)
rails runner lib/competitor_analysis/run.rb --cached

# Single competitor only (for testing)
rails runner lib/competitor_analysis/run.rb --competitor=cupsdirect

# Review pending matches interactively
rails runner lib/competitor_analysis/run.rb --review
```

### First Run Workflow

1. Run script → scrapes competitors, generates candidate matches
2. Open `mappings.yml` → review `pending_review` section
3. Move good matches to `verified`, delete bad ones
4. Re-run with `--cached` → generates final report with verified matches

### Subsequent Runs

1. Run script → scrapes fresh prices, reuses verified mappings
2. New products appear in `pending_review` for review
3. Report shows price changes since last run

## File Structure

```
lib/
└── competitor_analysis/
    ├── run.rb                    # Main entry point
    ├── scrapers/
    │   ├── base_scraper.rb       # Shared Firecrawl logic
    │   ├── cupsdirect.rb         # CupsDirect-specific extraction
    │   ├── purple_planet.rb      # Purple Planet-specific extraction
    │   ├── ambican.rb            # Ambican-specific extraction
    │   └── takeaway_packaging.rb # Takeaway Packaging-specific extraction
    ├── matching/
    │   ├── matcher.rb            # Hybrid matching engine
    │   ├── normalizer.rb         # Category/size normalization
    │   └── mappings.yml          # Verified product mappings
    ├── reports/
    │   ├── csv_generator.rb      # CSV output
    │   └── markdown_generator.rb # Summary report
    └── cache/                    # Cached scrape data (gitignored)

tmp/
└── competitor_analysis/          # Output files (gitignored)
    ├── comparison_YYYY-MM-DD.csv
    └── report_YYYY-MM-DD.md
```

### Version Control

**Committed:**
- All Ruby code in `lib/competitor_analysis/`
- `mappings.yml` (verified product mappings)

**Gitignored:**
- `lib/competitor_analysis/cache/` (scraped data)
- `tmp/competitor_analysis/` (output reports)

## Cost Estimate

Using Firecrawl API:
- **Per run:** ~500-750 credits
- **Hobby plan ($19/mo):** 3,000 credits - covers ~4 quarterly runs
- Alternative: Self-host Firecrawl (open source) for zero API cost

## Future Enhancements (Not in Scope)

- Price change alerts
- Historical price tracking
- Automated scheduling
- Web UI for mapping review
