# AI SEO Engine Design
**Date:** 2025-11-15
**Goal:** Replace £600/month SEO agency with AI-powered content generation and optimization system

## Executive Summary

Build a Rails engine (`seo_ai_engine`) that discovers SEO opportunities, generates optimized content using Claude AI, and tracks performance. The system will focus on creating commercial content (buying guides, product comparisons) and optimizing product descriptions to drive organic traffic.

**Target Savings:** £510/month (85% cost reduction)
**Payback Period:** 12 months
**Implementation:** 12 weeks

---

## System Architecture

### Three Core Pipelines

#### 1. Opportunity Discovery Pipeline (Daily)
Identifies high-value SEO opportunities by combining:
- **Google Search Console API**: Real search queries, impressions, clicks, positions
- **SerpAPI**: Competitor rankings, content gaps, SERP analysis
- **Opportunity Scorer**: Assigns 0-100 score based on search volume, competition, relevance, and quick-win potential

**Output:** Prioritized list of opportunities (new content to create, existing pages to optimize)

#### 2. Content Generation Pipeline (On-demand)
Three-stage Claude workflow for quality content:
1. **ContentStrategist**: Analyzes opportunity, creates detailed content brief (structure, keywords, competitor analysis, product linking strategy)
2. **ContentWriter**: Generates draft content (blog posts, guides, product descriptions) using brief and real product data
3. **ContentReviewer**: Quality check for accuracy, brand voice, SEO best practices, natural product mentions

**Output:** Draft content saved for manual review before publishing

#### 3. Performance Monitoring Pipeline (Weekly)
Tracks published content performance and ROI:
- GSC data for each published piece (impressions, clicks, position trends)
- Traffic value estimation (clicks × £2 CPC)
- ROI calculation vs agency cost
- Flags underperforming content for refresh

**Output:** Performance dashboard showing system value and content effectiveness

---

## Technology Stack

### Rails Engine: `seo_ai_engine`
- **Mountable:** at `/seo_ai` in host app
- **Database:** PostgreSQL (shared with host app)
- **Background Jobs:** Solid Queue (existing host app setup)
- **LLM Integration:** `ruby-llm` gem (provider-agnostic)

### External Dependencies
- **LLM Provider:** Anthropic Claude (via `ruby-llm`)
  - Strategist/Writer: `claude-sonnet-4-5` (quality)
  - Reviewer: `claude-haiku-4` (cost optimization)
- **Google Search Console API:** OAuth 2.0 (free)
- **SerpAPI:** £40/month (100 searches, SERP analysis)

### Host App Integration Points
```ruby
# Engine reads from host app
config.product_class = "Product"
config.category_class = "Category"
config.user_class = "User"

# Host app displays engine content
- BlogsController renders SeoAi::ContentItem
- Sitemap includes published content
- Related products/categories linked in articles
```

---

## Data Model

### Core Tables (Engine)

**`seo_ai_opportunities`**
- Discovered opportunities from GSC + SerpAPI
- Fields: keyword, opportunity_type, score (0-100), search_volume, current_position, competition_difficulty, metadata (JSONB), status
- Indexed: keyword, status, score

**`seo_ai_content_briefs`**
- Strategy output from ContentStrategist
- Fields: opportunity_id, target_keyword, search_intent, suggested_structure (JSONB), competitor_analysis (JSONB), product_links (JSONB), created_by_model, generation_cost

**`seo_ai_content_drafts`**
- Generated content awaiting review
- Fields: content_brief_id, content_type, title, body (markdown), meta_title, meta_description, target_keywords (array), status, quality_score, review_notes (JSONB), reviewed_by_user_id, reviewed_at
- Statuses: pending_review, approved, rejected, published

**`seo_ai_content_items`**
- Published content (live on site)
- Fields: content_draft_id, slug, title, body, meta_title, meta_description, target_keywords, published_at, related_product_ids (array), related_category_ids (array)
- Indexed: slug (unique), published_at

**`seo_ai_performance_snapshots`**
- Weekly performance tracking
- Fields: content_item_id, period_start/end, impressions, clicks, avg_position, ctr, keyword_positions (JSONB), traffic_value_gbp

**`seo_ai_budget_tracking`**
- Monthly API cost tracking
- Fields: month, gsc_requests, serpapi_requests, llm_requests, llm_cost_gbp, serpapi_cost_gbp, total_cost_gbp, content_pieces_generated, avg_cost_per_piece

---

## Opportunity Scoring Algorithm

### New Content Opportunities (Blogs/Guides)
- **Search volume** (40 points): Higher volume = higher priority
- **Competition difficulty** (30 points): Weak competitors = easier to rank
- **Product relevance** (20 points): Can naturally link to products = better ROI
- **Content gap** (10 points): Thin competitor content = opportunity

### Existing Page Optimization
- **Impression volume** (30 points): Already getting visibility
- **Low CTR penalty** (30 points): Position 5 with 2% CTR = meta tag problem
- **Quick win bonus** (25 points): Position 11-20 = one push to page 1
- **Traffic potential** (15 points): Estimated clicks if moved up 5 positions

**Scoring Thresholds:**
- 70-100: High priority (generate immediately)
- 50-69: Medium priority (queue for later)
- 0-49: Low priority (dismiss or revisit in 3 months)

---

## Content Generation Workflow

### 1. Opportunity Review (Manual)
User reviews `/seo_ai/opportunities` dashboard:
- View scored opportunities sorted by priority
- Filter by type (new_content, optimize_existing, quick_win)
- Dismiss irrelevant opportunities
- Click "Generate Content" on selected opportunity

### 2. Content Brief Creation (Automated)
`SeoAi::ContentStrategist.new(opportunity).create_brief`

**Claude Prompt Includes:**
- Target keyword + search intent (informational vs commercial)
- Top 10 competitor URLs from SerpAPI with content analysis
- Suggested article structure (H2s, sections, estimated word count)
- Product linking opportunities (which products to feature)
- Internal linking strategy (related categories, other articles)

**Output:** Structured brief saved to `seo_ai_content_briefs`

### 3. Draft Generation (Automated)
`SeoAi::ContentWriter.new(brief).generate_draft`

**Claude Prompt Includes:**
- Content brief from step 2
- Brand voice guidelines (from engine config)
- Real product data (Product model with variants, prices, descriptions)
- SEO requirements (target keyword density, readability, header structure)

**Output:** Full article in markdown + meta tags

### 4. Quality Review (Automated)
`SeoAi::ContentReviewer.new(draft).review`

**Claude Checks:**
- Factual accuracy (flags unverified claims like "100% compostable")
- Brand voice consistency
- SEO best practices (keyword usage, header hierarchy, content length)
- Natural product mentions (not spammy)
- Link validation (all product/category links valid)

**Output:** Quality score (0-100) + review notes (suggested improvements)

### 5. Manual Review & Publishing
User reviews draft at `/seo_ai/content_drafts/:id`:
- Read generated content
- Review quality score and reviewer notes
- Edit if needed (inline markdown editor)
- Approve → Creates `SeoAi::ContentItem` (published)
- Reject → Mark as rejected with reason

### 6. Display on Site (Automated)
Host app `BlogsController` displays published content:
- Renders markdown as HTML
- Shows related products (pulled from `related_product_ids`)
- Shows related categories
- Includes structured data (Article schema)
- Adds to sitemap automatically

---

## Error Handling & Safeguards

### API Rate Limits
```ruby
SeoAi.configure do |config|
  config.serpapi_daily_limit = 3      # Max 3 keywords/day
  config.max_drafts_per_week = 10     # Don't overwhelm review queue
  config.claude_timeout = 120         # 2min max per request
  config.max_retries = 3              # Exponential backoff
end
```

### Content Safety Checks
Before saving draft:
- **Plagiarism check**: High similarity to competitor content = flag for review
- **Product accuracy**: Verify mentioned products exist, specs are correct
- **Compliance**: Flag claims requiring verification (compostability, certifications)
- **Link validation**: All internal links resolve (products/categories exist)

### Cost Controls
Monthly budget tracking with alerts:
- API costs >£100/month → Something's wrong, investigate
- Claude costs >£50/month → Generating too much unused content
- Content success rate <70% → Prompts need improvement
- Weekly email summary: costs, content published, traffic value

### Failure Modes
- **API down**: Log error, retry with exponential backoff (max 3×), alert admin if all fail
- **Claude timeout**: Queue for retry, max 3 attempts, then manual review
- **Low quality score** (<50): Don't save draft, alert for prompt improvement
- **GSC auth expires**: Email alert to reconnect OAuth

---

## Performance Monitoring

### Weekly Performance Tracking
`rails seo:track_performance` (runs weekly via cron)

**For each published content item:**
1. Fetch GSC data (last 7 days): impressions, clicks, avg position for target keywords
2. Calculate trends: week-over-week % change
3. Estimate traffic value: clicks × £2 CPC estimate
4. Flag underperformers: published >8 weeks ago, <50 impressions/week

**Site-wide metrics:**
- Total content pieces published
- Aggregate traffic from AI content (vs baseline)
- Total cost (API + Claude)
- Traffic value (estimated revenue from organic clicks)
- ROI: (Traffic value - Costs) vs £600/month agency

### Dashboard (`/seo_ai/performance`)
- **Overview cards**: Total content, total traffic, monthly cost, net savings
- **Content performance table**: Each article with impressions, clicks, position, trend
- **Cost breakdown chart**: Monthly API costs vs budget
- **ROI calculator**: System value vs agency cost (visual progress to breakeven)

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1-2)
**Goal:** Basic engine structure and data fetching

- [ ] Generate Rails engine: `rails plugin new seo_ai_engine --mountable`
- [ ] Create database migrations (all 6 tables)
- [ ] Setup models with validations and associations
- [ ] Build basic admin UI (opportunities, drafts, settings)
- [ ] Integrate Google Search Console OAuth
- [ ] Integrate SerpAPI client
- [ ] Create rake task: `seo:test_apis` (verify credentials work)

**Deliverable:** Can fetch and display GSC + SERP data in admin

---

### Phase 2: Opportunity Discovery (Week 3-4)
**Goal:** Automated daily opportunity discovery

- [ ] Build opportunity scoring algorithm
- [ ] Create rake task: `seo:discover_opportunities` (daily cron)
- [ ] GSC integration: Fetch queries, pages, impressions, clicks, positions
- [ ] SerpAPI integration: Analyze target keywords, competitor rankings
- [ ] Build opportunities dashboard (view, filter by score/type, dismiss)
- [ ] Add seed keyword management (CRUD for target keyword list)

**Deliverable:** Daily discovery of scored SEO opportunities

---

### Phase 3: Content Generation (Week 5-7)
**Goal:** AI-powered draft generation

- [ ] Integrate `ruby-llm` gem with Claude API
- [ ] Configure LLM models (Sonnet for writing, Haiku for review)
- [ ] Build `SeoAi::ContentStrategist` service (brief creation)
- [ ] Build `SeoAi::ContentWriter` service (draft generation)
- [ ] Build `SeoAi::ContentReviewer` service (quality check)
- [ ] Product integration: Pull real product data for prompts
- [ ] Create content draft review UI (read, edit, approve/reject)
- [ ] Add background job: `SeoAi::ContentGenerationJob`
- [ ] Implement safety checks (plagiarism, accuracy, compliance)

**Deliverable:** Generate draft blog posts/guides from opportunities

---

### Phase 4: Publishing & Display (Week 8-9)
**Goal:** Published content live on site

- [ ] Create host app `BlogsController` (index, show)
- [ ] Build blog templates (article layout with related products)
- [ ] Integrate with sitemap generator
- [ ] Add structured data for articles (Article schema.org)
- [ ] Implement related product/category display
- [ ] Add social share buttons (Open Graph tags)
- [ ] Build internal linking suggestions (to/from products)

**Deliverable:** Published content visible on site, indexed by Google

---

### Phase 5: Performance Tracking (Week 10-11)
**Goal:** Prove the system's value

- [ ] Build rake task: `seo:track_performance` (weekly cron)
- [ ] GSC performance data fetching per content item
- [ ] Calculate traffic value and ROI metrics
- [ ] Create performance dashboard UI
- [ ] Build cost tracking (API usage, budget alerts)
- [ ] Add email reports (weekly summary to admin)
- [ ] Implement underperformer flagging (for refresh)

**Deliverable:** Dashboard showing traffic, costs, savings vs agency

---

### Phase 6: Polish & Optimization (Week 12+)
**Goal:** Refine and optimize

- [ ] Refine Claude prompts based on content quality feedback
- [ ] A/B test cheaper models for some tasks (Haiku for briefs?)
- [ ] Add email alerts for high-value opportunities (score >90)
- [ ] Build content refresh workflow (update underperformers)
- [ ] Add product description optimization (use existing descriptions)
- [ ] Add meta tag optimization for existing pages
- [ ] Performance tuning (caching, N+1 queries, job optimization)

**Deliverable:** Optimized system ready for long-term use

---

## Cost Analysis

### Monthly Operating Costs

**API Costs:**
- SerpAPI: £40/month (100 searches = 3-4 keywords/day)
- Claude API: £30-50/month (10-15 articles + briefs + reviews)
- Google Search Console: Free
- **Total APIs: ~£70-90/month**

**vs Current Spend:**
- SEO Agency: £600/month
- **Net Savings: £510/month (85% reduction)**

### Cost Per Content Piece
- Claude Strategist (brief): £0.50
- Claude Writer (1,500-2,000 words): £2-3
- Claude Reviewer (quality check): £0.30
- SerpAPI (SERP analysis): £1.20
- **Total: ~£4-5 per article**
- **vs Agency: £50-100 per article**

### Development Investment
- 12 weeks development time
- Contract rate estimate: £500/week × 12 = £6,000
- Or in-house: ~120 hours dev time
- **Payback period: 12 months** (£6,000 / £510 savings/month)

### ROI Projections

**Year 1:**
- Development cost: £6,000 (one-time)
- Operating costs: £1,080 (£90/month × 12)
- Total investment: £7,080
- Agency savings: £7,200 (£600/month × 12)
- **Net benefit: £120** (breakeven)

**Year 2+:**
- Operating costs: £1,080/year
- Agency savings: £7,200/year
- **Net benefit: £6,120/year** (85% cost reduction)

**3-Year ROI:** £18,360 saved (vs £21,600 agency cost)

---

## Success Metrics

### Month 1-3 (Proof of Concept)
- [ ] 5-10 blog posts published
- [ ] 500+ organic impressions/month from new content
- [ ] Quality score avg >70/100
- [ ] Manual review time <30min per draft

### Month 4-6 (Scale & Optimize)
- [ ] 20-30 total blog posts published
- [ ] 2,000+ organic impressions/month
- [ ] 100+ clicks/month from AI content
- [ ] At least 3 posts ranking in top 10 for target keywords

### Month 7-12 (Prove ROI)
- [ ] 40-50 total blog posts published
- [ ] 5,000+ organic impressions/month
- [ ] 300+ clicks/month (£600 estimated value = breakeven)
- [ ] Cost per article <£5
- [ ] Agency contract cancelled

---

## Future Enhancements (Post-Launch)

### Additional Content Types
- [ ] Product description optimization (use existing 3-tier system)
- [ ] Meta tag optimization for category pages
- [ ] FAQ schema generation (People Also Ask optimization)
- [ ] Video script generation (YouTube SEO)

### Advanced Features
- [ ] Automated internal linking suggestions
- [ ] Content refresh detection (auto-update stale articles)
- [ ] Competitor content monitoring (alerts when they publish)
- [ ] Multi-language content generation (translate high-performers)

### Productization (If Desired)
- [ ] Multi-tenant support (multiple e-commerce sites)
- [ ] White-label admin UI
- [ ] API for external integrations
- [ ] Marketplace for Claude prompts (community templates)
- [ ] SaaS pricing: £49-199/month per site

---

## Risk Mitigation

### Technical Risks
- **Claude quality varies**: Implement multi-stage review, manual approval required
- **API rate limits**: Daily limits configured, alerts for overuse
- **Cost overruns**: Monthly budget tracking, automatic alerts at £100/month
- **Low-quality output**: Quality scoring, reject drafts <50/100

### Business Risks
- **Google algorithm changes**: Monitor rankings, adapt content strategy
- **Claude pricing increases**: `ruby-llm` allows easy provider switching
- **Time to ROI**: Manual review burden in first 3 months (improve prompts to reduce)
- **Content accuracy**: Legal review for compliance claims (compostability, certifications)

### Mitigation Strategies
- Start with low-risk content (informational guides, not product specs)
- Manual approval required for all content (no auto-publishing)
- Weekly performance reviews (catch issues early)
- Maintain agency relationship first 3 months (fallback if system fails)

---

## Next Steps

### Immediate Actions
1. **Decision point**: Commit to 12-week implementation timeline
2. **Setup**: Create SerpAPI account (£40/month plan)
3. **Setup**: Enable Google Search Console API access
4. **Setup**: Get Anthropic API key (Claude access)
5. **Planning**: Use superpowers:writing-plans to create detailed implementation plan

### Phase 1 Kickoff (Week 1)
1. **Workspace**: Create git worktree for isolated development
2. **Engine**: Generate Rails engine scaffold
3. **Database**: Create and run initial migrations
4. **APIs**: Test GSC and SerpAPI connections
5. **Admin UI**: Basic CRUD for opportunities and settings

---

## Conclusion

This AI SEO engine will replace your £600/month agency with a £90/month automated system, saving £510/month (85% reduction) while generating higher-quality, product-focused content. The 12-week implementation will pay for itself within a year, then deliver £6,000+ annual savings.

The Rails engine architecture also positions this as a potential standalone product (SaaS opportunity) if results prove strong.

**Key Success Factors:**
- Manual review ensures quality (no blind auto-publishing)
- Three-stage Claude workflow catches errors early
- Focus on commercial content (buying guides) drives conversions
- Performance tracking proves ROI continuously
- Cost controls prevent runaway API spending

Ready to build this?
