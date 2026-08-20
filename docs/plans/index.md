# Plans

Dated feature and design plans. Statuses were researched against git history and the current codebase in July 2026: shipped means the core landed (sometimes under different names), abandoned means never built or fully reverted, superseded links to the successor. Note the January 2026 model restructure renamed ProductVariant to Product and Product to ProductFamily; older shipped plans use the pre-restructure vocabulary, so trust the status, not the class names.

# Active

* [B2B Organic Roadmap 2026-07](/plans/2026-07-07-b2b-organic-roadmap.md) - Task-by-task execution of the [B2B organic growth strategy](/seo/b2b-organic-growth-plan-2026-07.md).
* [Hormozi Trilogy Implementation 2026-08](/plans/2026-08-17-hormozi-trilogy-implementation.md) - Consolidated four-phase checklist merging the build orders of the three Hormozi proposals (Money Model, Grand Slam Offer, Leads).
* [Gap Coverage Plan 2026-08](/plans/2026-08-19-gap-coverage-plan.md) - Closes the Ahrefs content gap with rankable commercial pages: batch 1 is eight category retargets plus three new pages, gated on the 2026-10-15 GSC checkpoint.
* [Product Copy and Specs 2026-08](/plans/2026-08-21-product-copy-and-specs.md) - Replaces formulaic product descriptions with facts in three sequenced moves: promote fit into the spec table from the curated mappings, fix the spec vocabulary, then cut the prose back.

# Shipped

* [Branding Page Redesign](/plans/2025-01-10-branding-page-redesign.md) - Branding landing page with hero, trust badges, showcase and CTA.
* [Product Add-ons](/plans/2025-10-22-product-addons.md) - Lids step in the branded configurator; the add-ons carousel was later removed.
* [Product Configuration System](/plans/2025-10-22-product-configuration-system.md) - Organizations, options and branded pricing; the option tables were later removed in the restructure.
* [Product Consolidation](/plans/2025-10-22-product-consolidation.md) - Catalog re-seeded from CSV to consolidate colour and size duplicates.
* [Product Photo Architecture](/plans/2025-11-03-product-photo-architecture.md) - Dual product and lifestyle photo system with hover swap.
* [Product Photos Implementation](/plans/2025-11-03-product-photos-implementation.md) - Task breakdown for the dual photo system.
* [Advertising Optimization](/plans/2025-11-06-advertising-optimization.md) - Shopping feed enhancements and conversion tracking; roughly half shipped as designed.
* [Comprehensive SEO Implementation](/plans/2025-11-06-comprehensive-seo-implementation.md) - Programmatic SEO foundation: structured data, sitemap, robots, canonicals, metas.
* [FAQ Section](/plans/2025-11-06-faq-section.md) - YAML-backed FAQ page with FAQPage schema; per-category DB FAQs came later.
* [Matching Lids Configurator](/plans/2025-11-06-matching-lids-configurator.md) - Compatible-lids join table and configurator step; superseded by the [2026-08 overhaul](/plans/2026-08-18-compatible-lids-overhaul.md).
* [Admin Ordering Controls Design](/plans/2025-11-08-admin-ordering-controls-design.md) - acts_as_list ordering for categories and products.
* [Admin Ordering Controls](/plans/2025-11-08-admin-ordering-controls.md) - Task breakdown for the ordering controls.
* [Category Page Lighthouse Audit](/plans/2025-11-24-category-page-lighthouse-audit-design.md) - Audit workflow; outputs live in `/audits/`.
* [Homepage Accessibility Audit](/plans/2025-11-24-homepage-accessibility-audit.md) - WCAG 2.1 AA audit and applied fixes for the homepage.
* [Product Page Accessibility Audit](/plans/2025-11-24-product-page-accessibility-audit.md) - WCAG 2.1 AA audit and applied fixes for product pages.
* [Branded Products URL Separation](/plans/2025-11-25-branded-products-url-separation-design.md) - /branded-products namespace split from the standard catalog.
* [Marketing Proposal Design](/plans/2025-11-27-afida-marketing-proposal-design.md) - Drafting plan for the 2025 partnership proposal; see [proposals](/proposals/index.md) for its fate.
* [Variant Samples Implementation](/plans/2025-12-01-variant-samples-implementation.md) - Up to 5 free variant samples with flat-rate shipping.
* [B2B Price List](/plans/2025-12-12-b2b-price-list-design.md) - /price-list with filtering and Excel and PDF export.
* [Product Lines Consolidation](/plans/2025-12-12-product-lines-consolidation.md) - Napkins, straws and cutlery consolidated into configurable pages.
* [Homepage Branding Section Redesign](/plans/2025-12-14-homepage-branding-section-redesign.md) - Photo collage, headline, trust badges and CTA; final copy differs from spec.
* [Price List PDF Branding](/plans/2025-12-14-price-list-pdf-branding.md) - Logo, value propositions and branded footer on the PDF export.
* [Custom Quote Request CTA](/plans/2025-12-15-custom-quote-request-cta-design.md) - Product page CTA for custom size, quantity or material requests.
* [Sign-up and Accounts](/plans/2025-12-15-sign-up-and-accounts-design.md) - Sign-up flow, post-checkout conversion, reordering, account settings.
* [Scheduled Reorder](/plans/2025-12-16-scheduled-reorder-design.md) - Scheduled reorders via one-time charges on a saved payment method.
* [User Address Storage](/plans/2025-12-17-user-address-storage.md) - Saved delivery addresses prefill Stripe Checkout.
* [Unified Variant Selector](/plans/2025-12-18-unified-variant-selector-design.md) - Accordion variant selector; the model shape has since moved on.
* [Reorder Schedule Conversion Page](/plans/2026-01-06-reorder-schedule-conversion-page-design.md) - Flexibility-first redesign of the reorder setup page.
* [Variant Pages](/plans/2026-01-10-variant-pages-design.md) - One page per SKU plus shop search; executed via the Product/ProductFamily restructure.
* [Admin Title Builder](/plans/2026-01-13-admin-title-builder-design.md) - Title Builder fieldset with live preview in the admin product form.
* [Blog Foundation](/plans/2026-01-14-blog-foundation-design.md) - blog_posts table, markdown rendering, public and admin CRUD.
* [Search Results Redesign](/plans/2026-01-14-search-results-redesign.md) - Search modal switched from grid to horizontal list rows.
* [Email Signup Discount](/plans/2026-01-16-email-signup-discount-design.md) - Cart email-signup discount; later evolved to 10% whole-order coupon.
* [Structured Events](/plans/2026-01-16-structured-events-design.md) - Rails.event structured reporting flowing to Logtail.
* [Collections and Curated Samples](/plans/2026-01-17-collections-and-curated-samples.md) - Audience-based Collections and curated sample packs.
* [Outrank Webhook Integration](/plans/outrank-webhook-integration.md) - Webhook creating draft BlogPosts from Outrank content.
* [Compatible Lids Overhaul](/plans/2026-08-18-compatible-lids-overhaul.md) - Curated join table as sole lid-display truth, admin opened to all container types, cart lid reminder, propose/review/apply data pipeline; shipped 2026-08-20 with 432 curated mappings.
* [Product Page Buy Box Overhaul](/plans/2026-08-20-pdp-buy-box-overhaul.md) - One primary CTA, lids attached as compact checkbox cards in the main form, the reverse fits-these-containers view on lid pages, per-unit pricing, live total, a counting-down free-delivery hint and a pinned media column.

# Superseded

* [Separate Option Selectors](/plans/2025-10-22-separate-option-selectors.md) - Replaced by the [variant pages architecture](/plans/2026-01-10-variant-pages-design.md).
* [Sample Pack Design](/plans/2025-11-30-sample-pack-design.md) - Replaced by [variant-level samples](/plans/2025-12-01-variant-samples-implementation.md).

# Abandoned

* [Competitor Price Analysis](/plans/2025-12-23-competitor-price-analysis-design.md) - Firecrawl-based competitor price scraper; never built.
* [Greenwash or Not? Design](/plans/2025-12-24-greenwash-or-not-design.md) - Swipe-game greenwash checker for backlinks; never built, may resurface after the July 2026 SEO gate.
* [Greenwash or Not? Certifications](/plans/greenwash-or-not-certifications.md) - Certification research content for the unbuilt tool.
* [Product Option Value Labels](/plans/2026-01-06-product-option-value-labels-design.md) - Built, then fully reverted in the January 2026 model restructure.
