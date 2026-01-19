# SEO Audit Checklist for Afida

**Purpose:** Identify and fix SEO issues to improve organic search visibility
**Timeline:** Complete initial audit in Week 1, ongoing optimisation thereafter
**Tools needed:** Google Search Console, Screaming Frog (or similar), PageSpeed Insights

---

## Part 1: Technical SEO

### Crawlability & Indexing

- [ ] **Robots.txt** - Verify at `afida.com/robots.txt`
  - Should allow Googlebot
  - Should block /admin/, /cart, /checkout
  - Should reference sitemap
  - Current: `RobotsController` handles this ✓

- [ ] **XML Sitemap** - Verify at `afida.com/sitemap.xml`
  - All products included
  - All categories included
  - No broken URLs
  - Submitted to Google Search Console
  - Current: `SitemapsController` + `SitemapGeneratorService` ✓

- [ ] **Google Search Console Setup**
  - Site verified
  - Sitemap submitted
  - No critical errors in Coverage report
  - Check for manual actions (should be none)

- [ ] **Indexing Status**
  - Run `site:afida.com` in Google
  - Compare indexed pages vs expected pages
  - Investigate any major gaps

### Site Speed

- [ ] **Core Web Vitals** - Test via PageSpeed Insights
  - LCP (Largest Contentful Paint) < 2.5s
  - FID (First Input Delay) < 100ms
  - CLS (Cumulative Layout Shift) < 0.1

- [ ] **Page Speed** - Target scores
  - Mobile: > 70
  - Desktop: > 85

- [ ] **Common Speed Issues**
  - [ ] Images optimised (WebP, lazy loading)
  - [ ] JavaScript minimised
  - [ ] CSS minimised
  - [ ] Browser caching enabled
  - [ ] GZIP compression enabled
  - [ ] CDN for static assets

### Mobile Friendliness

- [ ] **Mobile-Friendly Test** - Google's tool
  - Pass/fail status
  - No content wider than screen
  - Tap targets adequately sized

- [ ] **Responsive Design Check**
  - Test on iPhone, Android
  - Navigation works
  - Forms usable
  - Images scale properly

### Security & HTTPS

- [ ] **HTTPS Everywhere**
  - All pages on HTTPS
  - No mixed content warnings
  - HTTP redirects to HTTPS
  - SSL certificate valid

### URL Structure

- [ ] **Clean URLs**
  - Readable: `/products/single-wall-hot-cup` ✓
  - No ID numbers in URLs (using slugs) ✓
  - Hyphens not underscores
  - Lowercase

- [ ] **Canonical Tags**
  - Every page has canonical
  - Self-referencing on unique pages
  - Pagination handled properly

---

## Part 2: On-Page SEO

### Title Tags

- [ ] **Home Page**
  - Includes brand + primary keyword
  - 50-60 characters
  - Compelling, click-worthy

- [ ] **Category Pages**
  - Format: `[Category] | Eco-Friendly [Type] | Afida`
  - Unique per category
  - Include primary keyword

- [ ] **Product Pages**
  - Format: `[Product Name] | [Category] | Afida`
  - Unique per product
  - Include product-specific keywords
  - Current: Uses `meta_title` with fallback ✓

- [ ] **Title Tag Audit**
  - No duplicates
  - None too long (>60 chars)
  - None too short (<30 chars)
  - None missing

### Meta Descriptions

- [ ] **All Pages Have Descriptions**
  - 150-160 characters
  - Include call to action
  - Include primary keyword naturally
  - Current: `meta_description` fields with fallbacks ✓

- [ ] **Meta Description Audit**
  - No duplicates
  - None too long (>160 chars)
  - None missing
  - Compelling (affects CTR)

### Heading Structure

- [ ] **H1 Tags**
  - One H1 per page
  - Contains primary keyword
  - Describes page content

- [ ] **Heading Hierarchy**
  - Logical H1 > H2 > H3 structure
  - No skipped levels
  - Keywords in subheadings where natural

### Content Quality

- [ ] **Product Descriptions**
  - Unique (not manufacturer copy)
  - Detailed enough (100+ words)
  - Include keywords naturally
  - Address customer questions
  - Current: Three-tier system (short/standard/detailed) ✓

- [ ] **Category Descriptions**
  - Introductory content on category pages
  - 150-300 words
  - Include category keywords
  - Internal links to products

- [ ] **Thin Content Check**
  - No pages with <100 words
  - No duplicate content
  - No doorway pages

### Image SEO

- [ ] **Alt Text**
  - All images have alt text
  - Descriptive, includes keywords where relevant
  - Not keyword stuffed

- [ ] **File Names**
  - Descriptive: `single-wall-hot-cup-8oz.jpg`
  - Not: `IMG_001234.jpg`

- [ ] **Image Optimisation**
  - Compressed file sizes
  - Appropriate dimensions
  - Modern formats (WebP)

---

## Part 3: Structured Data

### Product Schema

- [ ] **Product Pages**
  - Schema.org Product markup
  - Includes: name, description, image, price, availability
  - Current: `product_structured_data` helper ✓

- [ ] **Test in Rich Results Test**
  - No errors
  - Eligible for rich snippets

### Organisation Schema

- [ ] **Site-Wide**
  - Schema.org Organization markup
  - Includes: name, logo, contact info
  - Current: `organization_structured_data` helper ✓

### Breadcrumb Schema

- [ ] **Navigation Pages**
  - BreadcrumbList markup
  - Matches visible breadcrumbs
  - Current: `breadcrumb_structured_data` helper ✓

### Validation

- [ ] **Google Rich Results Test**
  - Test representative pages
  - No errors
  - All structured data valid

- [ ] **Schema Markup Validator**
  - schema.org validator
  - No warnings

---

## Part 4: Internal Linking

### Site Architecture

- [ ] **Crawl Depth**
  - All products reachable in ≤3 clicks from home
  - Category > Product structure
  - No orphan pages

- [ ] **Navigation**
  - Main categories in primary nav
  - Logical hierarchy
  - Mobile-friendly menu

### Internal Links

- [ ] **Contextual Links**
  - Product descriptions link to related products
  - Category pages link to products
  - Blog posts link to products (if blog exists)

- [ ] **Anchor Text**
  - Descriptive (not "click here")
  - Varied (not same text everywhere)
  - Keywords where natural

### Footer Links

- [ ] **Important Pages in Footer**
  - Categories
  - Contact
  - About
  - Policies

---

## Part 5: Local SEO (If Applicable)

### Google Business Profile

- [ ] **Claimed and Verified**
  - Business name correct
  - Address accurate
  - Phone number
  - Website URL

- [ ] **Optimised**
  - Categories selected
  - Description written
  - Photos added
  - Hours listed

### Local Keywords

- [ ] **UK-Specific Terms**
  - "UK" in key pages where relevant
  - "wholesale UK"
  - Location pages if serving specific areas

---

## Part 6: Off-Page SEO

### Backlink Profile

- [ ] **Audit Current Backlinks**
  - Use Ahrefs, Moz, or SEMrush
  - Identify quality links
  - Identify toxic links (disavow if needed)

- [ ] **Competitor Backlink Analysis**
  - Who links to competitors?
  - Opportunities for Afida

### Link Building Opportunities

- [ ] **Directories**
  - Relevant business directories
  - Industry-specific listings
  - Sustainable business directories

- [ ] **Content Opportunities**
  - Guest posts on hospitality blogs
  - Sustainability publications
  - Industry news sites

- [ ] **Partnerships**
  - Supplier links
  - Customer testimonials (with links back)
  - Industry associations

---

## Part 7: Keyword Strategy

### Keyword Research

- [ ] **Identify Target Keywords**
  - Primary: "eco friendly cups", "compostable food containers"
  - Secondary: Product-specific terms
  - Long-tail: "8oz compostable coffee cups wholesale UK"

- [ ] **Search Intent Analysis**
  - Informational vs transactional
  - Match content type to intent
  - Product pages for transactional
  - Guides for informational

### Keyword Mapping

- [ ] **Assign Keywords to Pages**
  - Each page targets 1-2 primary keywords
  - No keyword cannibalisation
  - Document in spreadsheet

| Page | Primary Keyword | Secondary Keywords |
|------|-----------------|-------------------|
| Home | eco friendly packaging supplies uk | sustainable packaging |
| Hot Cups Category | paper coffee cups wholesale | disposable hot cups |
| Single Wall Cups | single wall paper cups | single wall coffee cups |

### Content Gaps

- [ ] **Competitor Analysis**
  - What do competitors rank for?
  - What pages are we missing?
  - Opportunities for new content

---

## Part 8: Content Opportunities

### Blog/Resource Section

- [ ] **Educational Content Ideas**
  - "Guide to Choosing Eco-Friendly Packaging"
  - "Paper vs Plastic: Environmental Impact"
  - "How to Store Compostable Products"
  - "packaging supplies Checklist for Events"

- [ ] **Product-Adjacent Content**
  - "Best Cups for Coffee Shops"
  - "Sustainable Packaging Trends 2024"
  - "Compostable vs Biodegradable: What's the Difference?"

### FAQ Content

- [ ] **Product FAQs**
  - Add FAQ schema
  - Answer common questions
  - Target long-tail keywords

- [ ] **Current FAQs** - Already in sitemap ✓

---

## Part 9: Competitor Analysis

### Identify Competitors

- [ ] **Direct Competitors**
  - Who ranks for target keywords?
  - Similar product range
  - Similar UK focus

- [ ] **Analyse Their SEO**
  - Domain authority
  - Top ranking pages
  - Content strategy
  - Backlink sources

### Competitive Gaps

- [ ] **Where They're Weak**
  - Keywords they don't target
  - Content they don't have
  - Technical issues

- [ ] **Where They're Strong**
  - What to emulate
  - Realistic targets

---

## Part 10: Monitoring & Reporting

### Google Search Console

- [ ] **Weekly Checks**
  - Coverage errors
  - New crawl issues
  - Manual actions

- [ ] **Monthly Review**
  - Impressions trend
  - Click trend
  - Average position
  - Top queries
  - Top pages

### Rank Tracking

- [ ] **Track Target Keywords**
  - Use SEMrush, Ahrefs, or free tools
  - Monitor weekly
  - Track competitors too

### Organic Traffic

- [ ] **GA4 Reports**
  - Organic search traffic
  - Landing pages
  - Conversions from organic
  - Revenue from organic

---

## Quick Wins Priority List

### Do First (Week 1)
1. Google Search Console setup + sitemap submission
2. Fix any crawl errors
3. Verify all products have meta titles/descriptions
4. Check robots.txt and sitemap
5. Test page speed, fix critical issues

### Do Next (Week 2-3)
1. Review and improve product descriptions
2. Add structured data validation
3. Fix any Core Web Vitals issues
4. Internal linking audit
5. Image optimisation

### Ongoing (Month 1+)
1. Keyword research and content planning
2. Competitor analysis
3. Link building outreach
4. Content creation
5. Monthly reporting

---

## SEO Tools Checklist

### Free Tools
- [ ] Google Search Console (must have)
- [ ] Google Analytics 4 (must have)
- [ ] Google PageSpeed Insights
- [ ] Google Rich Results Test
- [ ] Google Mobile-Friendly Test
- [ ] Screaming Frog (free up to 500 URLs)

### Paid Tools (Nice to Have)
- [ ] Ahrefs or SEMrush (backlinks, keywords)
- [ ] Screaming Frog license (if >500 pages)
- [ ] Surfer SEO (content optimisation)

---

## Monthly SEO Report Template

```
AFIDA SEO PERFORMANCE - [MONTH YEAR]

ORGANIC TRAFFIC
===============
Sessions: X,XXX (vs last month: +/-X%)
Users: X,XXX
Pageviews: X,XXX

CONVERSIONS FROM ORGANIC
========================
Transactions: XX
Revenue: £X,XXX
Conversion Rate: X.X%

KEYWORD RANKINGS
================
[Primary keyword 1]: Position X (was: X)
[Primary keyword 2]: Position X (was: X)
[Primary keyword 3]: Position X (was: X)

TOP ORGANIC LANDING PAGES
=========================
1. /products/xxx - XXX sessions
2. /categories/xxx - XXX sessions
3. /xxx - XXX sessions

TECHNICAL ISSUES
================
Crawl errors: X
Core Web Vitals: Pass/Fail
Index coverage: X pages

ACTIONS TAKEN
=============
- [What you did this month]

NEXT MONTH FOCUS
================
- [What you'll do next]
```
