# GEO (Generative Engine Optimization) Audit Report

**Site:** afida.com
**Date:** 2026-03-10
**Audited by:** Claude AI GEO Auditor

---

## 1. Executive Summary

Afida's website demonstrates **above-average GEO readiness** compared to typical e-commerce sites. The site already has a functional `llms.txt`, comprehensive JSON-LD structured data across all major page types (Product, Organization, FAQPage, Article, BreadcrumbList, CollectionPage, LocalBusiness, ContactPage), a well-structured FAQ section with schema markup, and clean server-rendered HTML via Rails/Hotwire. However, the `robots.txt` lacks explicit AI crawler directives (meaning all are allowed by default, which is good, but explicit allow rules would strengthen crawl confidence), the `llms.txt` is missing URL links per the spec, several key pages have headings optimized for branding rather than AI-queryable questions, and the Organization schema is missing critical `sameAs` links (no Facebook, Twitter/X, or Google Business Profile). The homepage meta description is solid but some category pages may have empty meta descriptions. With 5-8 targeted improvements, Afida could move from "AI-discoverable" to "AI-citable" — the difference between being found and being quoted.

---

## 2. Scores

| Category | Score | Grade |
|---|---|---|
| AI Crawler Access | 78/100 | B+ |
| llms.txt | 62/100 | C+ |
| Citability | 55/100 | C |
| Structured Data (JSON-LD) | 82/100 | A- |
| Content Structure for AI | 60/100 | C+ |
| Brand & Entity Signals | 70/100 | B |
| **Overall GEO Readiness** | **68/100** | **C+** |

---

## 3. Quick Wins (under 1 hour each)

1. **Add explicit AI crawler Allow rules to robots.txt** — Add named `User-agent` blocks for GPTBot, ClaudeBot, PerplexityBot, etc. with `Allow: /`. Takes 10 minutes, immediately signals AI-friendliness.

2. **Add URL links to llms.txt** — The current `llms.txt` has good content but lacks the URL links the spec requires. Add links to key pages (shop, about, contact, FAQ, categories). Takes 15 minutes.

3. **Add `sameAs` links to Organization schema** — Add Facebook, Twitter/X, Google Business Profile URLs to the `organization_structured_data` helper. Takes 10 minutes, strengthens entity recognition.

4. **Rephrase 3-5 key headings as questions** — Change headings like "Our Story" to "How did Afida start?" or add question-phrased H2s to category pages ("What are the best eco-friendly takeaway containers?"). Takes 30 minutes.

5. **Add a WebSite schema with SearchAction** — Add `WebSite` schema with `potentialAction: SearchAction` to the homepage. This helps AI engines understand the site's search capability and structure. Takes 15 minutes.

---

## 4. Detailed Findings

### 4.1 AI Crawler Access

**robots.txt analysis** (dynamically generated via `RobotsController`):

The current robots.txt uses a single `User-agent: *` wildcard rule:

```
User-agent: *
Allow: /

Disallow: /admin/
Disallow: /cart
Disallow: /checkout
Disallow: /signin
Disallow: /signup
Disallow: /products/*/quick_add

Sitemap: https://afida.com/sitemap.xml
```

| Crawler | Status | Notes |
|---|---|---|
| GPTBot (OpenAI) | ALLOWED (implicit) | No explicit rule; falls under `*` wildcard |
| ChatGPT-User | ALLOWED (implicit) | No explicit rule |
| OAI-SearchBot | ALLOWED (implicit) | No explicit rule |
| ClaudeBot (Anthropic) | ALLOWED (implicit) | No explicit rule |
| Claude-Web | ALLOWED (implicit) | No explicit rule |
| PerplexityBot | ALLOWED (implicit) | No explicit rule |
| Google-Extended | ALLOWED (implicit) | No explicit rule |
| Googlebot | ALLOWED (implicit) | No explicit rule |
| Bingbot | ALLOWED (implicit) | No explicit rule |
| FacebookBot | ALLOWED (implicit) | No explicit rule |
| Applebot-Extended | ALLOWED (implicit) | No explicit rule |
| Bytespider (TikTok) | ALLOWED (implicit) | No explicit rule |
| cohere-ai | ALLOWED (implicit) | No explicit rule |
| Diffbot | ALLOWED (implicit) | No explicit rule |

**Good:**
- No blanket blocks that would inadvertently prevent AI crawling
- Sensible disallow rules for admin, cart, checkout, auth pages
- Turbo Frame endpoints (`quick_add`) correctly blocked
- Sitemap reference present
- Staging domain blocking prevents duplicate content

**Needs improvement:**
- No explicit `User-agent` blocks for AI crawlers. While the wildcard allows all, explicit allow rules signal intentional AI-friendliness and prevent future wildcard changes from accidentally blocking AI crawlers.
- No `crawl-delay` consideration for AI bots that may crawl aggressively

**Sitemap:**
- Dynamic XML sitemap via `SitemapGeneratorService` — comprehensive coverage
- Includes: homepage, all static pages, categories, products, blog posts, collections, sample packs
- Proper `lastmod`, `changefreq`, and `priority` values
- Legacy Wix sitemap files exist in root directory (should be removed or redirected)

**Score: 78/100**

---

### 4.2 llms.txt Analysis

**File exists:** Yes (`/public/llms.txt`)

**Current content analysis:**

```markdown
# Afida

> Afida is a UK-based B2B supplier of eco-friendly disposable food and drink
> packaging for cafes, restaurants, takeaways, and catering businesses.

## About
[good descriptive paragraph]

## Product Categories
[bullet list of 13 categories]

## Key Information
[website, location, customers, sustainability, ordering]
```

**Good:**
- Follows the basic llms.txt structure (title, blockquote description, sections)
- Content is accurate and comprehensive
- Product categories are well-enumerated
- Key business information is included

**Issues:**
- **Missing URL links** — The llms.txt spec requires sections to contain links to relevant pages. Currently, no URLs are provided for categories, product pages, or informational pages.
- **Missing `llms-full.txt` reference** — The spec allows linking to a more detailed version
- **No pricing information** — Key facts like "free delivery over £100" are mentioned but specific product pricing structure is absent
- **No mention of branded/custom products** — A major service offering is missing
- **Title says "B2B" but the repo is "afida-b2c"** — the site serves both B2B and B2C customers; the llms.txt should reflect this

**Score: 62/100**

---

### 4.3 Citability Scoring

Citability measures how likely AI engines are to extract and quote content from your pages.

#### Homepage (`/`)

| Criterion | Score | Notes |
|---|---|---|
| Self-contained blocks | 5/20 | Hero text is short slogans, not self-contained statements. "Trusted by 500+ UK businesses" is a good signal but lacks context. |
| Fact-rich content | 8/20 | Good: free delivery threshold (£100), next-day delivery, "500+ UK businesses". Missing: founding year, product count, specific client names in text. |
| Optimal block length | 5/20 | Content is too fragmented — short taglines rather than 134-167 word paragraphs. |
| Answers a question | 5/20 | Doesn't directly answer questions like "Where can I buy eco-friendly packaging in the UK?" |
| Authority signals | 10/20 | Client logos (The Ritz, Marriott), Google Business Profile badge, "500+ UK businesses" — but these are visual, not text. |
| **Total** | **33/100** | |

#### About Page (`/about`)

| Criterion | Score | Notes |
|---|---|---|
| Self-contained blocks | 14/20 | The timeline tells a complete story. Each chapter is self-contained. |
| Fact-rich content | 12/20 | Good: founded 2020, founders named (Marco Bungish, Tariq), started as B&B Eco, notable clients (The Ritz, Marriott, Hawksmoor). |
| Optimal block length | 8/20 | Paragraphs are short (40-60 words each). Could be expanded. |
| Answers a question | 10/20 | Partially answers "Who is Afida?" and "When was Afida founded?" |
| Authority signals | 14/20 | Named founders, notable clients, growth narrative. |
| **Total** | **58/100** | |

#### Contact Page (`/contact`)

| Criterion | Score | Notes |
|---|---|---|
| Self-contained blocks | 12/20 | Phone and email clearly displayed. Business hours in plain text. |
| Fact-rich content | 16/20 | Phone: 0203 302 7719, Email: hello@afida.com, Hours: Mon-Fri 9am-5pm. All in plain text. |
| Optimal block length | 5/20 | Very minimal text content — functional but not citable. |
| Answers a question | 14/20 | Directly answers "How do I contact Afida?" |
| Authority signals | 8/20 | Real phone number, business hours — good. Missing: full address, company registration. |
| **Total** | **55/100** | |

#### FAQ Page (`/faqs`)

| Criterion | Score | Notes |
|---|---|---|
| Self-contained blocks | 18/20 | Each Q&A is perfectly self-contained. |
| Fact-rich content | 14/20 | Good specific answers about MOQs, materials, delivery, returns policy. |
| Optimal block length | 12/20 | Most answers are 40-80 words — slightly short for optimal AI citation. |
| Answers a question | 20/20 | By definition — every block directly answers a question. |
| Authority signals | 8/20 | Company-specific policies, product knowledge. |
| **Total** | **72/100** | |

#### Product Pages (`/products/:slug`)

| Criterion | Score | Notes |
|---|---|---|
| Self-contained blocks | 12/20 | Product title, price, description, SKU — all clearly structured. |
| Fact-rich content | 16/20 | Price, pack size, SKU, delivery info, material details. |
| Optimal block length | 8/20 | Short descriptions. Detailed descriptions vary by product. |
| Answers a question | 10/20 | Partially answers "How much do X cost?" and "What size X do you have?" |
| Authority signals | 10/20 | Brand attribution, GBP rating integration possible. |
| **Total** | **56/100** | |

**Average Citability Score: 55/100**

---

### 4.4 Structured Data (JSON-LD)

**Existing schema types detected:**

| Schema Type | Location | Status |
|---|---|---|
| Organization | Global (layout) | Present |
| Product | `/products/:slug` | Present |
| BreadcrumbList | Products, Categories, About, Contact, Blog | Present |
| Article | `/blog/:slug` | Present |
| FAQPage | `/faqs` | Present |
| CollectionPage | `/categories/:slug`, `/collections/:slug` | Present |
| ContactPage | `/contact` | Present |
| LocalBusiness | `/contact` (nested in ContactPage) | Present |
| WebPage + ItemList | Sample packs | Present |

**Good:**
- Comprehensive coverage of major page types
- Product schema includes pricing tiers (AggregateOffer), availability, shipping details, SKU/GTIN
- Blog posts have proper Article schema with dates
- FAQPage schema correctly aggregates all questions
- BreadcrumbList on all key page types
- Google Business Profile rating integration (when configured)
- CollectionPage for category and collection pages

**Issues & Missing schemas:**

| Missing Schema | Where | Impact |
|---|---|---|
| `WebSite` with `SearchAction` | Homepage/Layout | HIGH — Helps AI engines understand site search capability |
| `Brand` (standalone) | Global | MEDIUM — Currently only nested in Product |
| `HowTo` | Blog posts (where applicable) | LOW — Could enhance tutorial content |
| `OfferCatalog` | Shop/Category pages | MEDIUM — Would help AI understand product range |
| `Review` / individual reviews | Product pages | HIGH — Currently only aggregate rating from GBP |

**Validation issues:**

1. **Organization schema**: Missing `address` property (PostalAddress) — only present on ContactPage's LocalBusiness
2. **Organization schema**: `logo` uses a relative Vite asset path — should be absolute URL for schema.org compliance
3. **Organization schema**: `sameAs` only has LinkedIn + Instagram — missing Facebook, Twitter/X, Google Business Profile
4. **Product schema**: `brand` is always "Afida" but for Vegware products, it should be "Vegware"
5. **LocalBusiness schema**: Missing `streetAddress`, `postalCode`, `addressLocality` in address — only has `addressCountry: "GB"`
6. **Article schema**: `publisher` is missing `logo` property (recommended by Google)

**Score: 82/100**

---

### 4.5 Content Structure for AI

**Heading structure analysis:**

| Page | H1 | AI-Friendly? | Recommendation |
|---|---|---|---|
| Homepage | Dynamic (e.g. "Eco-Friendly Packaging For UK Businesses") | Partially | Add a subheading like "Where to buy sustainable packaging supplies online" |
| About | "How Two Mates With A Box Of Straws Built A Packaging Company" | Yes | Engaging and question-adjacent. |
| Contact | "Talk To A Human" | No | Should be "How to Contact Afida" or similar |
| FAQs | "Frequently Asked Questions (FAQs)" | Partially | Good, but individual Q&A headings are the real AI targets |
| Products | Product name (e.g. "8oz Single Wall Paper Coffee Cup") | Yes | Product names are exactly what people ask about |
| Categories | Category name (e.g. "Cups & Lids") | Partially | Could be "What types of cups and lids does Afida offer?" |
| Shop | "Shop" | No | Should be "Buy Eco-Friendly Packaging Supplies Online" |

**FAQ section quality:**
- 20+ well-structured Q&A pairs across 6 categories
- Questions are naturally phrased ("What types of packaging products do you offer?")
- Answers contain internal links
- FAQPage schema properly generated
- Searchable FAQ interface

**Key facts in plain text:**
- Phone: 0203 302 7719 — in contact page and FAQ sidebar
- Email: hello@afida.com — in contact page and footer
- Hours: Monday-Friday, 9am-5pm — in contact page
- Delivery: Free over £100 — in hero and product pages
- Address: Partial (return address exists in delivery policy, but not prominently displayed)

**JavaScript rendering:**
- Rails/Hotwire (Turbo + Stimulus) — content is **server-side rendered**
- All critical content available without JavaScript
- Interactive elements (cart, search modal, quantity selectors) are progressive enhancements
- This is a major positive for AI crawler accessibility

**Meta descriptions:**
- Homepage: "Premium eco-friendly packaging supplies for UK businesses. Pizza boxes, cups, napkins, and takeaway containers. Free delivery over £100." — Good, reads like a potential AI citation
- About: "From a living room startup to supplying The Ritz and Marriott..." — Good storytelling hook
- Contact: Functional but not citation-worthy
- FAQs: "FAQs about Afida's eco-friendly packaging supplies. Find answers about products, shipping, returns, and ordering." — Good
- Categories: Uses `@category.meta_description` — may be empty for some categories

**Score: 60/100**

---

### 4.6 Brand & Entity Signals

**NAP (Name, Address, Phone) consistency:**

| Signal | Contact Page | Footer | FAQ Sidebar | Schema | Consistent? |
|---|---|---|---|---|---|
| Business name | Afida | Afida | Afida | Afida | Yes |
| Phone | 0203 302 7719 | Not shown | 0203 302 7719 | +44-203-302-7719 | Mostly (format varies) |
| Email | hello@afida.com | Not shown | info@afida.com | hello@afida.com | **Inconsistent** |
| Address | Not displayed | Not displayed | Not shown | Country only (GB) | **Missing** |

**Issues:**
- Email inconsistency: `hello@afida.com` vs `info@afida.com` vs `sales@afida.com` on different pages
- Full street address not displayed on public pages (only in return policy)
- Phone number not in footer
- No company registration number visible

**Organization schema `sameAs`:**
- LinkedIn: `https://www.linkedin.com/company/afidasupplies`
- Instagram: `https://www.instagram.com/afidasupplies`
- Missing: Facebook, Twitter/X, Google Business Profile, YouTube (if applicable)

**Brand name consistency:**

| Location | Brand in Title? | Brand in H1? | Brand in Meta Description? |
|---|---|---|---|
| Homepage | Yes ("... \| Afida") | Yes (dynamic) | Yes |
| About | Yes | No (creative title) | Yes |
| Contact | Yes | No ("Talk To A Human") | Yes |
| Products | Yes ("... \| Afida") | No (product name only) | Varies |
| Categories | Yes | No (category name only) | Varies |
| Blog | Varies | No | Varies |

**Author/expertise signals:**
- About page mentions founders (Marco Bungish, Tariq) by name
- Notable clients listed: The Ritz, Marriott, Hawksmoor
- No dedicated team page with credentials/bios
- No author attribution on blog posts (authored by "Afida" organization)
- Founded 2020, previously "B&B Eco" — origin story present
- "500+ UK businesses" trust signal on homepage

**Score: 70/100**

---

## 5. Generated Assets

### 5.1 Recommended llms.txt

```markdown
# Afida

> Afida is a UK-based supplier of eco-friendly disposable food and drink packaging for cafes, restaurants, takeaways, and catering businesses. Free UK delivery on orders over £100.

Afida supplies sustainable disposable packaging to hospitality businesses and consumers across the UK. Our product range includes paper coffee cups and lids, takeaway food containers, pizza boxes, paper bags, napkins, straws, wooden cutlery, ice cream cups, bagasse eco containers, and plates and trays. We offer bulk pricing with free UK delivery on orders over £100 (excl. VAT). Founded in 2020, Afida (formerly B&B Eco) is trusted by 500+ businesses including The Ritz, Marriott, and Hawksmoor.

## Product Categories

- [Cups & Lids](https://afida.com/categories/cups-and-lids): Single wall, double wall, and ripple wall paper coffee cups with matching sip lids
- [Ice Cream Cups](https://afida.com/categories/ice-cream-cups): Paper ice cream and dessert cups in sizes from 4oz to 10oz
- [Napkins](https://afida.com/categories/napkins): Cocktail napkins, dinner napkins, airlaid napkins, and dispenser napkins
- [Pizza Boxes](https://afida.com/categories/pizza-boxes): Kraft corrugated pizza boxes from 7 inch to 16 inch
- [Straws](https://afida.com/categories/straws): Paper straws and biodegradable bamboo straws
- [Takeaway Containers](https://afida.com/categories/takeaway-containers): Kraft salad bowls, soup containers, and food boxes with lids
- [Takeaway Boxes](https://afida.com/categories/takeaway-boxes): Burger boxes, chip boxes, and general takeaway food boxes
- [Food Containers](https://afida.com/categories/food-containers): Portion pots, deli containers, soup cups, and lids
- [Bags](https://afida.com/categories/bags): Paper bags with handles, carrier bags, and kraft bags
- [Cutlery](https://afida.com/categories/cutlery): Wooden forks, knives, spoons, and cutlery kits
- [Plates & Trays](https://afida.com/categories/plates-and-trays): Palm leaf plates, bagasse plates, and platter boxes
- [Bagasse Eco Range](https://afida.com/categories/bagasse-eco-range): Compostable clamshells, burger boxes, and food containers

## Services

- [Custom Branded Packaging](https://afida.com/branded-products): Custom printing with your logo and branding on cups, boxes, bags, and more
- [Free Sample Packs](https://afida.com/samples): Try before you buy — order free product samples with low-cost delivery

## Key Pages

- [Shop All Products](https://afida.com/shop)
- [About Afida](https://afida.com/about)
- [Frequently Asked Questions](https://afida.com/faqs)
- [Contact Us](https://afida.com/contact)
- [Blog](https://afida.com/blog)
- [Delivery & Returns](https://afida.com/delivery-returns)

## Key Information

- Website: https://afida.com
- Phone: +44 203 302 7719
- Email: hello@afida.com
- Location: United Kingdom
- Hours: Monday–Friday, 9am–5pm GMT
- Customers: Cafes, restaurants, takeaways, ice cream parlours, caterers, and event organisers
- Sustainability: Focus on eco-friendly, biodegradable, compostable, and recyclable packaging
- Delivery: Free UK delivery on orders over £100 (excl. VAT), next-day delivery available
- Founded: 2020 (originally as B&B Eco)
```

### 5.2 Recommended robots.txt Additions

Add these lines to `RobotsController#robots_txt_content` before the sitemap line:

```
# AI Search Engine Crawlers - Explicitly Allowed
User-agent: GPTBot
Allow: /
Disallow: /admin/
Disallow: /cart
Disallow: /checkout
Disallow: /signin
Disallow: /signup

User-agent: ChatGPT-User
Allow: /

User-agent: OAI-SearchBot
Allow: /

User-agent: ClaudeBot
Allow: /
Disallow: /admin/
Disallow: /cart
Disallow: /checkout
Disallow: /signin
Disallow: /signup

User-agent: Claude-Web
Allow: /

User-agent: PerplexityBot
Allow: /
Disallow: /admin/
Disallow: /cart
Disallow: /checkout
Disallow: /signin
Disallow: /signup

User-agent: Google-Extended
Allow: /

User-agent: Applebot-Extended
Allow: /

User-agent: cohere-ai
Allow: /

User-agent: Diffbot
Allow: /
```

### 5.3 Missing JSON-LD: WebSite Schema with SearchAction

Add to `app/helpers/seo_helper.rb`:

```ruby
def website_structured_data
  {
    "@context": "https://schema.org",
    "@type": "WebSite",
    "name": "Afida",
    "url": root_url,
    "description": "Eco-friendly packaging supplies for UK businesses",
    "potentialAction": {
      "@type": "SearchAction",
      "target": {
        "@type": "EntryPoint",
        "urlTemplate": "#{root_url}search?q={search_term_string}"
      },
      "query-input": "required name=search_term_string"
    }
  }.to_json
end
```

### 5.4 Missing JSON-LD: Enhanced Organization Schema

Update the existing `organization_structured_data` method with:

```ruby
def organization_structured_data
  data = {
    "@context": "https://schema.org",
    "@type": "Organization",
    "name": "Afida",
    "alternateName": "B&B Eco",
    "url": root_url,
    "logo": "#{root_url}#{vite_asset_path('images/logo.svg').delete_prefix('/')}",
    "description": "Eco-friendly packaging supplies for UK businesses. Paper cups, takeaway containers, pizza boxes, and more.",
    "foundingDate": "2020",
    "telephone": "+44-203-302-7719",
    "email": "hello@afida.com",
    "address": {
      "@type": "PostalAddress",
      "streetAddress": "Unit 27, The Metro Centre, Dwight Rd",
      "addressLocality": "Watford",
      "addressRegion": "Hertfordshire",
      "postalCode": "WD18 9SB",
      "addressCountry": "GB"
    },
    "areaServed": {
      "@type": "Country",
      "name": "United Kingdom"
    },
    "contactPoint": {
      "@type": "ContactPoint",
      "contactType": "Customer Service",
      "telephone": "+44-203-302-7719",
      "email": "hello@afida.com",
      "availableLanguage": "English",
      "hoursAvailable": {
        "@type": "OpeningHoursSpecification",
        "dayOfWeek": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
        "opens": "09:00",
        "closes": "17:00"
      }
    },
    "sameAs": [
      "https://www.linkedin.com/company/afidasupplies",
      "https://www.instagram.com/afidasupplies",
      gbp_configured? ? gbp_profile_url : nil
      # Add when available:
      # "https://www.facebook.com/afidasupplies",
      # "https://twitter.com/afidasupplies",
    ].compact
  }

  if gbp_configured?
    data[:aggregateRating] = {
      "@type": "AggregateRating",
      "ratingValue": gbp_rating_data[:rating].to_s,
      "reviewCount": gbp_rating_data[:review_count].to_s,
      "bestRating": "5",
      "worstRating": "1"
    }
  end

  data.to_json
end
```

---

## 6. Priority Action Plan

Ordered by impact vs effort (highest ROI first):

| # | Action | Impact | Effort | Category |
|---|---|---|---|---|
| 1 | **Update llms.txt with URLs and expanded content** | HIGH | 15 min | llms.txt |
| 2 | **Add explicit AI crawler Allow rules to robots.txt** | HIGH | 15 min | Crawler Access |
| 3 | **Add WebSite schema with SearchAction to homepage** | HIGH | 20 min | Structured Data |
| 4 | **Add full address to Organization schema** | HIGH | 10 min | Brand Signals |
| 5 | **Add sameAs social profile links** | MEDIUM | 10 min | Brand Signals |
| 6 | **Standardize email across all pages** (use hello@afida.com consistently) | MEDIUM | 15 min | Brand Signals |
| 7 | **Add phone number to footer** | MEDIUM | 5 min | Brand Signals |
| 8 | **Add question-style H2s to category pages** (e.g. "What eco-friendly cups does Afida offer?") | MEDIUM | 45 min | Content Structure |
| 9 | **Expand homepage with a 150-word intro paragraph** below the hero | MEDIUM | 30 min | Citability |
| 10 | **Add "About Afida" summary paragraph to footer** (2-3 sentences with key facts) | MEDIUM | 15 min | Citability |
| 11 | **Ensure all category meta_descriptions are populated** (run `rake seo:validate`) | MEDIUM | 30 min | Content Structure |
| 12 | **Add author bios/credentials to blog posts** | LOW | 1-2 hrs | Brand Signals |
| 13 | **Create a dedicated team page** with founder bios | LOW | 2-3 hrs | Brand Signals |
| 14 | **Add OfferCatalog schema to shop page** | LOW | 30 min | Structured Data |
| 15 | **Expand FAQ answers to 100-150 words each** | LOW | 2-3 hrs | Citability |
| 16 | **Remove legacy Wix sitemap files** from root directory | LOW | 5 min | Crawler Access |
| 17 | **Create llms-full.txt** with complete product catalog | LOW | 1-2 hrs | llms.txt |

---

## Appendix: What AI Engines Look For

For context, here's what each major AI search engine prioritizes when selecting sources to cite:

- **ChatGPT / GPTBot**: Self-contained factual paragraphs, structured data, clean HTML, llms.txt
- **Claude / ClaudeBot**: Well-organized content, clear headings, factual density, authority signals
- **Perplexity**: Schema.org markup, FAQ sections, direct answers to questions, recent content
- **Google AI Overviews**: Existing SEO signals (E-E-A-T), structured data, FAQ schema, breadcrumbs, reviews
- **Gemini**: Similar to Google; emphasizes entity recognition, Knowledge Graph alignment, structured data

The common thread: **structured, fact-rich, self-contained content blocks that directly answer questions people ask.**
