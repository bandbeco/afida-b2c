# UTM Parameter Strategy

**Purpose:** Consistent tracking of all marketing campaigns for accurate attribution
**Rule:** Every paid link must have UTM parameters. No exceptions.

---

## What Are UTM Parameters?

UTM parameters are tags added to URLs that tell analytics where traffic came from:

```
https://afida.com/products/single-wall-cups?utm_source=google&utm_medium=cpc&utm_campaign=hot-cups-search
```

GA4 reads these and attributes conversions to the right campaign.

---

## The Five UTM Parameters

| Parameter | Required | Purpose | Example |
|-----------|----------|---------|---------|
| `utm_source` | Yes | Where traffic comes from | `google`, `facebook`, `newsletter` |
| `utm_medium` | Yes | Marketing medium | `cpc`, `email`, `social` |
| `utm_campaign` | Yes | Campaign name | `hot-cups-search`, `black-friday-2024` |
| `utm_term` | Optional | Paid search keywords | `eco+friendly+cups` |
| `utm_content` | Optional | Differentiate ads/links | `headline-a`, `image-2` |

---

## Naming Conventions

### Source (`utm_source`)

Use the platform name, lowercase:

| Platform | Source Value |
|----------|--------------|
| Google Ads | `google` |
| Microsoft/Bing Ads | `bing` |
| Meta (Facebook/Instagram) | `facebook` |
| LinkedIn | `linkedin` |
| Email campaigns | `newsletter` or `email` |
| Affiliate partners | Partner name: `foodserviceworld` |

### Medium (`utm_medium`)

Use standardised medium types:

| Type | Medium Value | When to Use |
|------|--------------|-------------|
| Paid search | `cpc` | Google/Bing search ads |
| Paid social | `paid_social` | Facebook, Instagram, LinkedIn ads |
| Display ads | `display` | Banner ads, GDN |
| Shopping ads | `shopping` | Google Shopping, Meta Catalog |
| Email | `email` | Newsletter, promotional emails |
| Organic social | `social` | Unpaid social posts |
| Referral | `referral` | Partner links |
| Retargeting | `retargeting` | Remarketing campaigns |

### Campaign (`utm_campaign`)

Format: `[category]-[descriptor]-[type]`

**Examples:**
- `hot-cups-search` - Hot cups, search campaign
- `cold-cups-shopping` - Cold cups, shopping campaign
- `brand-awareness-display` - Brand awareness, display
- `black-friday-2024` - Seasonal promotion
- `new-customer-welcome` - Email sequence

**Rules:**
- Lowercase only
- Hyphens between words (not underscores or spaces)
- Be descriptive but concise
- Include year for seasonal campaigns

### Term (`utm_term`)

For paid search, captures the keyword.

**Google Ads auto-fills this** when auto-tagging is enabled (recommended).

For manual tagging:
- `eco+cups` (use + for spaces)
- `{keyword}` (dynamic insertion in Google Ads)

### Content (`utm_content`)

Use to differentiate:
- Different ads in same campaign
- Different links in same email
- A/B test variants

**Examples:**
- `headline-sustainability` vs `headline-price`
- `hero-image` vs `sidebar-cta`
- `variant-a` vs `variant-b`

---

## Campaign URL Templates

### Google Ads Search

Auto-tagging handles most tracking, but for manual:

```
{lpurl}?utm_source=google&utm_medium=cpc&utm_campaign={campaignid}&utm_term={keyword}&utm_content={creative}
```

**Recommendation:** Enable auto-tagging in Google Ads (Settings → Account Settings → Auto-tagging). It's more reliable and captures more data.

### Google Shopping

```
{lpurl}?utm_source=google&utm_medium=shopping&utm_campaign=shopping-{product_type}
```

### Meta (Facebook/Instagram)

```
https://afida.com/products/hot-cups?utm_source=facebook&utm_medium=paid_social&utm_campaign=hot-cups-prospecting&utm_content={{ad.name}}
```

Dynamic parameters in Meta:
- `{{campaign.name}}` - Campaign name
- `{{adset.name}}` - Ad set name
- `{{ad.name}}` - Ad name

### Email Campaigns

```
https://afida.com/shop?utm_source=newsletter&utm_medium=email&utm_campaign=weekly-deals-nov-2024&utm_content=hero-button
```

### LinkedIn Ads

```
https://afida.com/business?utm_source=linkedin&utm_medium=paid_social&utm_campaign=b2b-catering-managers&utm_content=carousel-ad
```

---

## UTM Builder Tool

Use Google's Campaign URL Builder:
https://ga-dev-tools.google/campaign-url-builder/

Or create a spreadsheet to maintain consistency:

| Campaign | Source | Medium | Full URL |
|----------|--------|--------|----------|
| Hot Cups Search | google | cpc | [generated URL] |
| Newsletter Nov | newsletter | email | [generated URL] |

---

## Channel Groupings in GA4

GA4 groups traffic into channels based on source/medium. Your UTMs should map cleanly:

| GA4 Channel | Your Source/Medium |
|-------------|-------------------|
| Organic Search | (automatic, no UTM needed) |
| Paid Search | google/cpc, bing/cpc |
| Paid Social | facebook/paid_social, linkedin/paid_social |
| Display | google/display, */display |
| Email | */email |
| Organic Social | facebook/social, instagram/social |

---

## Quick Reference Card

Print this and keep it handy:

```
UTM QUICK REFERENCE
===================

SOURCES:
google, bing, facebook, linkedin, newsletter, email

MEDIUMS:
cpc        = paid search
paid_social = paid social ads
display    = display/banner ads
shopping   = shopping ads
email      = email campaigns
social     = organic social

CAMPAIGN NAMING:
[product]-[goal]-[type]
hot-cups-conversions-search
brand-awareness-display

RULES:
✓ Always lowercase
✓ Use hyphens not spaces
✓ Be consistent
✓ Test before launching
```

---

## Testing UTM Links

Before launching any campaign:

1. **Click your tagged link**
2. **Check GA4 Real-Time:**
   - Reports → Real-time
   - Look for your traffic source
3. **Verify in GTM Preview:**
   - See UTM parameters in Page View tag

### Common Mistakes

| Mistake | Problem | Fix |
|---------|---------|-----|
| Spaces in values | Breaks URL | Use hyphens: `hot-cups` |
| Mixed case | Splits data | Always lowercase |
| Missing parameters | Poor attribution | Always include source, medium, campaign |
| Inconsistent naming | Can't aggregate | Use this document as reference |
| Forgetting to tag | Lost attribution | Checklist before launch |

---

## Campaign Launch Checklist

Before any paid campaign goes live:

- [ ] All destination URLs have UTM parameters
- [ ] Source matches platform (google, facebook, etc.)
- [ ] Medium matches ad type (cpc, paid_social, etc.)
- [ ] Campaign name follows convention
- [ ] Clicked test link and verified in GA4 real-time
- [ ] No spaces or special characters in UTM values
- [ ] Documented in campaign tracking spreadsheet

---

## Monthly Attribution Report

Pull this from GA4 for revenue share calculation:

**GA4 Path:** Reports → Acquisition → Traffic Acquisition

Filter by:
- Session source/medium
- Date range: Previous month

Export to spreadsheet and categorise:
- `google / cpc` → Paid Search (yours)
- `google / organic` → Organic Search (yours)
- `facebook / paid_social` → Paid Social (yours)
- `newsletter / email` → Email (yours)
- `(direct) / (none)` → Direct (not yours)
- Referral from non-partner sites → Not yours

---

## Afida-Specific Campaign Taxonomy

### Suggested Campaign Structure

**Search Campaigns:**
- `cups-hot-search` - Hot cups search
- `cups-cold-search` - Cold cups search
- `containers-food-search` - Food containers search
- `brand-search` - Brand terms (Afida)
- `competitor-search` - Competitor terms

**Shopping Campaigns:**
- `shopping-all-products` - All products
- `shopping-cups` - Cups category
- `shopping-containers` - Containers category
- `shopping-high-margin` - High margin products

**Social Campaigns:**
- `awareness-eco-social` - Eco/sustainability messaging
- `prospecting-hospitality-social` - Targeting hospitality
- `retargeting-cart-social` - Cart abandoners
- `retargeting-visitors-social` - Site visitors

**Email Campaigns:**
- `welcome-series` - New subscriber sequence
- `weekly-deals-[month]` - Weekly promotions
- `cart-abandonment` - Abandoned cart emails
- `reactivation` - Lapsed customer emails
