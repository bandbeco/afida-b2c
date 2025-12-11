# SEO AI Engine - Architecture Documentation

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Diagram](#architecture-diagram)
3. [Data Flow](#data-flow)
4. [Integration Points](#integration-points)
5. [API Configuration](#api-configuration)
6. [Deployment Checklist](#deployment-checklist)
7. [Troubleshooting](#troubleshooting)

## System Overview

The SEO AI Engine is a Rails engine that automates SEO opportunity discovery and content generation using AI. It reduces content creation costs from £600/article (agency baseline) to ~£3/article while maintaining quality.

### Key Features

- **Automated Discovery**: Daily keyword opportunity discovery from Google Search Console
- **AI Content Generation**: Full workflow from opportunity → brief → draft → published content
- **Quality Control**: AI-powered review with quality scoring (0-100)
- **Performance Tracking**: Monitor ranking improvements and ROI
- **Budget Management**: Track API costs and compare against agency baseline

### Technology Stack

- **Rails Engine**: Isolated namespace (SeoAiEngine::)
- **AI Provider**: Anthropic Claude API (Sonnet 3.5)
- **Search Data**: Google Search Console API (OAuth 2.0)
- **SERP Analysis**: SerpAPI
- **Background Jobs**: Solid Queue (Rails 8 default)
- **Database**: PostgreSQL 14+ with JSONB

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        SEO AI Engine                             │
│                   (Rails Engine @ /seo_ai)                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────────┐
        │         Background Job Orchestration        │
        │              (Solid Queue)                  │
        └─────────────────────────────────────────────┘
                     │              │
        ┌────────────┴────────┐    └─────────────────┐
        │                     │                      │
        ▼                     ▼                      ▼
┌───────────────┐   ┌──────────────────┐   ┌──────────────────┐
│  Discovery    │   │    Content       │   │  Performance     │
│     Job       │   │ Generation Job   │   │  Tracking Job    │
└───────────────┘   └──────────────────┘   └──────────────────┘
        │                     │                      │
        │                     │                      │
        ▼                     ▼                      ▼
┌───────────────────────────────────────────────────────────────┐
│                    Service Layer                               │
├───────────────────────────────────────────────────────────────┤
│  GscClient   │  SerpClient  │  OpportunityScorer              │
│  LlmClient   │  ContentStrategist │  ContentWriter            │
│  ContentReviewer │  BudgetTracker │  PerformanceAnalyzer      │
└───────────────────────────────────────────────────────────────┘
        │                     │                      │
        ▼                     ▼                      ▼
┌───────────────────────────────────────────────────────────────┐
│                    Data Models                                 │
├───────────────────────────────────────────────────────────────┤
│  Opportunity  │  ContentBrief  │  ContentDraft                │
│  ContentItem  │  PerformanceSnapshot  │  BudgetTracking       │
└───────────────────────────────────────────────────────────────┘
        │                     │                      │
        ▼                     ▼                      ▼
┌───────────────────────────────────────────────────────────────┐
│               External APIs & Services                         │
├───────────────────────────────────────────────────────────────┤
│  Google Search Console  │  Anthropic Claude  │  SerpAPI       │
└───────────────────────────────────────────────────────────────┘
        │                     │                      │
        ▼                     ▼                      ▼
┌───────────────────────────────────────────────────────────────┐
│                   Host Application                             │
├───────────────────────────────────────────────────────────────┤
│  Product Model  │  Category Model  │  User Model              │
│  Admin Dashboard  │  Blog Integration                         │
└───────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Opportunity Discovery Flow

```
User/Scheduler
      │
      ▼
OpportunityDiscoveryJob
      │
      ├─► GscClient ───────────► Google Search Console API
      │        │
      │        └─► Returns keywords with impressions/CTR/position
      │
      ├─► SerpClient ──────────► SerpAPI
      │        │
      │        └─► Returns SERP results for each keyword
      │
      ├─► OpportunityScorer
      │        │
      │        └─► Calculates score (0-100) based on:
      │            - Search volume (40%)
      │            - Competition (30%)
      │            - Product relevance (20%)
      │            - Content gap (10%)
      │
      └─► Save to Opportunity model (if score >= 30)
```

**Database Record Created:**
```ruby
Opportunity {
  keyword: "compostable coffee cups",
  opportunity_type: "new_content",
  score: 78,
  search_volume: 8100,
  competition_difficulty: "medium",
  status: "pending"
}
```

### 2. Content Generation Flow

```
Admin clicks "Generate Content"
      │
      ▼
ContentGenerationJob
      │
      ├─► Stage 1: ContentStrategist
      │        │
      │        ├─► LlmClient.generate_brief(opportunity)
      │        │        │
      │        │        └─► Claude API: Generate content strategy
      │        │
      │        └─► Creates ContentBrief with:
      │            - Target keyword
      │            - Suggested title
      │            - H2 suggestions
      │            - Word count target (1,500)
      │            - Key points to cover
      │
      ├─► Stage 2: ContentWriter
      │        │
      │        ├─► LlmClient.generate_content(brief)
      │        │        │
      │        │        └─► Claude API: Generate 1,500-word article
      │        │
      │        └─► Creates ContentDraft with:
      │            - Title, body (markdown)
      │            - Meta title, meta description
      │            - Target keywords array
      │            - Related product/category IDs
      │
      └─► Stage 3: ContentReviewer
               │
               ├─► LlmClient.review_content(draft)
               │        │
               │        └─► Claude API: Quality review
               │
               ├─► Check plagiarism (mock implementation)
               │
               └─► Updates draft with:
                   - Quality score (0-100)
                   - Review notes (strengths/improvements)
                   - SEO/readability scores
                   - Reviewer model version
```

**Database Records Created:**
```ruby
ContentBrief {
  opportunity_id: 123,
  target_keyword: "compostable coffee cups",
  suggested_structure: {
    title: "The Complete Guide to Compostable Coffee Cups",
    h2_suggestions: [...],
    word_count_target: 1500,
    key_points: [...]
  }
}

ContentDraft {
  content_brief_id: 456,
  title: "The Complete Guide to Compostable Coffee Cups",
  body: "# The Complete Guide...",
  quality_score: 75,
  status: "pending_review",
  review_notes: {
    strengths: [...],
    improvements: [...],
    plagiarism_check: { similarity_score: 0.0, status: "pass" }
  }
}
```

### 3. Approval & Publishing Flow

```
Admin reviews draft
      │
      ├─► Approve
      │        │
      │        ├─► ContentDraft.status = "approved"
      │        │
      │        ├─► Creates ContentItem with:
      │        │   - Slug generation from title
      │        │   - Published timestamp
      │        │   - Copy all content fields
      │        │
      │        ├─► ContentDraft.status = "published"
      │        │
      │        └─► Opportunity.status = "completed"
      │
      └─► Reject
               │
               ├─► ContentDraft.status = "rejected"
               │
               └─► Opportunity.status = "pending" (retry)
```

**Database Record Created:**
```ruby
ContentItem {
  content_draft_id: 789,
  slug: "compostable-coffee-cups-guide",
  title: "The Complete Guide to Compostable Coffee Cups",
  body: "...",
  published_at: "2025-11-16T12:00:00Z",
  related_product_ids: [1, 5, 12],
  related_category_ids: [3]
}
```

### 4. Performance Tracking Flow

```
PerformanceTrackingJob (daily)
      │
      ├─► For each published ContentItem
      │        │
      │        ├─► GscClient.search_analytics(slug URL)
      │        │        │
      │        │        └─► Google Search Console: Get metrics
      │        │
      │        └─► Creates PerformanceSnapshot with:
      │            - Impressions, clicks, CTR, position
      │            - Tracked date
      │            - Improvement vs. baseline
      │
      └─► PerformanceAnalyzer
               │
               └─► Calculates ROI:
                   - Agency cost (£600) vs AI cost (£3)
                   - Ranking improvements
                   - Traffic gained
```

## Integration Points

### Host Application Dependencies

The engine integrates with the host application through these models:

#### 1. Product Model

```ruby
# Expected interface
Product.all                  # Enumerable collection
Product.find(id)             # Find by ID
Product.pluck(:name)         # Extract names
product.name                 # Product name
product.category             # Associated category
product.id                   # Product ID for relationships
```

**Used by:**
- `OpportunityScorer` - Match keywords to products for relevance scoring
- `ContentStrategist` - Suggest related products in content brief
- `ContentWriter` - Link to relevant products in generated content

#### 2. Category Model

```ruby
# Expected interface
Category.all                 # Enumerable collection
Category.find(id)            # Find by ID
Category.pluck(:name)        # Extract names
category.name                # Category name
category.id                  # Category ID for relationships
```

**Used by:**
- `OpportunityScorer` - Match keywords to categories
- `ContentWriter` - Link to relevant categories

#### 3. User Model (Optional)

```ruby
# Expected interface
User.find(id)                # Find by ID
user.name                    # User name for attribution
```

**Used by:**
- Admin controllers - Authentication (if implemented)
- Content authorship tracking (future)

### Blog Integration (Optional)

To display generated content in your blog:

```ruby
# In your blog posts controller
class BlogPostsController < ApplicationController
  def show
    @content_item = SeoAiEngine::ContentItem.find_by(slug: params[:slug])

    if @content_item
      render "seo_ai_engine/content_items/show"
    else
      # Fall back to regular blog post lookup
      @post = BlogPost.find_by(slug: params[:slug])
    end
  end
end
```

Or mount the engine's routes:

```ruby
# config/routes.rb
mount SeoAiEngine::Engine, at: "/blog/ai"

# Content accessible at: /blog/ai/compostable-coffee-cups-guide
```

## API Configuration

### 1. Google Search Console (OAuth 2.0)

**Setup Steps:**

1. Create project in Google Cloud Console
2. Enable Google Search Console API
3. Create OAuth 2.0 credentials
4. Add authorized redirect URI: `http://localhost:3000/oauth/google/callback`
5. Get authorization code and exchange for refresh token

**Add to Rails credentials:**

```bash
rails credentials:edit
```

```yaml
google:
  oauth_client_id: YOUR_CLIENT_ID
  oauth_client_secret: YOUR_CLIENT_SECRET
  oauth_refresh_token: YOUR_REFRESH_TOKEN
  site_url: https://afida.com  # Your GSC property
```

**Testing:**

```ruby
client = SeoAiEngine::GscClient.new
results = client.search_analytics(
  start_date: 30.days.ago,
  end_date: Date.today,
  dimensions: ["query"],
  min_impressions: 10
)
```

### 2. SerpAPI

**Setup Steps:**

1. Sign up at https://serpapi.com
2. Get API key from dashboard
3. Choose pricing plan (free tier: 100 searches/month)

**Add to Rails credentials:**

```yaml
serpapi:
  api_key: YOUR_SERPAPI_KEY
```

**Testing:**

```ruby
client = SeoAiEngine::SerpClient.new
results = client.search("compostable coffee cups", location: "United Kingdom")
```

### 3. Anthropic Claude API

**Setup Steps:**

1. Sign up at https://console.anthropic.com
2. Create API key
3. Add billing information
4. Choose usage tier

**Add to Rails credentials:**

```yaml
anthropic:
  api_key: YOUR_ANTHROPIC_KEY
```

**Cost Estimation:**

- Brief generation: ~10,000 tokens = £0.50
- Content generation: ~50,000 tokens = £2.50
- Review: ~5,000 tokens = £0.30
- **Total per article: ~£3.30**

**Testing:**

```ruby
opportunity = SeoAiEngine::Opportunity.first
brief_response = SeoAiEngine::LlmClient.generate_brief(opportunity)
```

### Environment Variables

For production deployment:

```bash
# .env or hosting platform config
ANTHROPIC_API_KEY=sk-ant-...
SERPAPI_KEY=...
GOOGLE_OAUTH_CLIENT_ID=...
GOOGLE_OAUTH_CLIENT_SECRET=...
GOOGLE_OAUTH_REFRESH_TOKEN=...
```

## Deployment Checklist

### Pre-Deployment

- [ ] **Database Migrations**
  ```bash
  rails seo_ai_engine:install:migrations
  rails db:migrate
  ```

- [ ] **API Credentials Configured**
  - [ ] Google Search Console OAuth tokens
  - [ ] SerpAPI key
  - [ ] Anthropic Claude API key

- [ ] **Environment Variables Set**
  - [ ] Production credentials encrypted
  - [ ] API keys in environment or credentials

- [ ] **Background Job Queue**
  - [ ] Solid Queue configured and running
  - [ ] Job monitoring dashboard accessible

- [ ] **Scheduling Configured**
  - [ ] `config/recurring.yml` setup for daily discovery
  - [ ] Performance tracking job scheduled

### Post-Deployment

- [ ] **Verify Job Execution**
  ```bash
  # Run discovery job manually
  SeoAiEngine::OpportunityDiscoveryJob.perform_now

  # Check results
  SeoAiEngine::Opportunity.count
  ```

- [ ] **Test Content Generation**
  - [ ] Navigate to `/seo_ai/admin/opportunities`
  - [ ] Click "Generate Content" on top opportunity
  - [ ] Verify draft created with quality score

- [ ] **Monitor Budget Tracking**
  ```ruby
  SeoAiEngine::BudgetTracking.total_spent  # Should return 0.0 initially
  ```

- [ ] **Check Performance Metrics**
  - [ ] Access admin dashboard tabs
  - [ ] Verify data displays correctly

### Monitoring

**Key Metrics to Track:**

1. **Discovery Success Rate**
   - Opportunities found per run
   - Average opportunity score
   - Opportunities meeting threshold (>= 30)

2. **Content Generation Success Rate**
   - Drafts created successfully
   - Average quality score
   - Approval rate (approved/total)

3. **API Costs**
   - Daily/weekly/monthly spend
   - Cost per article
   - Budget vs. actual

4. **Performance Improvements**
   - Ranking improvements (30 days)
   - Traffic increases
   - ROI vs. agency baseline (£600/article)

**Logging:**

All jobs and services log to Rails logger:

```bash
# Production logs
tail -f log/production.log | grep "SeoAiEngine"

# Key log messages
# - OpportunityDiscoveryJob: Found X keywords, saved Y opportunities
# - ContentGenerationJob: Generated draft with quality score Z
# - LlmClient: Circuit breaker status, API calls
# - GscClient: OAuth expiration warnings
```

**Alerts to Configure:**

- OAuth token expiration (GscClient)
- Circuit breaker open (LlmClient)
- Budget threshold exceeded (80%, 90%, 100%)
- Job failures (Solid Queue error queue)

## Troubleshooting

### Common Issues

#### 1. OAuth Token Expired

**Symptoms:**
```
Google::Apis::AuthorizationError: Invalid Credentials
```

**Solution:**
1. Check logs for detailed instructions
2. Re-authorize with Google Cloud Console
3. Update credentials with new refresh token
4. Restart application

**Prevention:**
- Set up email alerts for OAuth errors
- Refresh tokens before expiration (90 days typically)

#### 2. Circuit Breaker Open

**Symptoms:**
```
LlmClient::CircuitOpenError: Circuit breaker is open due to 5 consecutive failures
```

**Solution:**
1. Check Anthropic API status
2. Verify API key is valid
3. Check billing/quota limits
4. Wait 15 minutes for circuit to half-open
5. Test with single request

**Prevention:**
- Monitor API quota usage
- Set up billing alerts
- Keep backup API key ready

#### 3. Low Quality Scores

**Symptoms:**
- Drafts consistently score < 50
- Cannot approve content

**Investigation:**
1. Review generated content manually
2. Check brief quality (Stage 1)
3. Verify prompt templates in LlmClient
4. Review Claude API response

**Solutions:**
- Adjust content brief template
- Improve keyword research data
- Update quality scoring criteria
- Regenerate with different opportunity

#### 4. No Opportunities Found

**Symptoms:**
- Discovery job runs but finds 0 opportunities

**Investigation:**
1. Check GSC has data (minimum 30 days)
2. Verify site URL in credentials
3. Check scoring threshold (score >= 30)
4. Review logs for API errors

**Solutions:**
- Lower scoring threshold temporarily
- Expand keyword filters
- Check GSC property verification
- Verify search_volume data from GSC

#### 5. Performance Tracking No Data

**Symptoms:**
- PerformanceSnapshot records but no metrics

**Investigation:**
1. Verify ContentItem slug matches actual URL
2. Check GSC has indexed the published content
3. Confirm minimum 3-7 days since publish

**Solutions:**
- Wait for GSC to index content
- Verify URL in GSC Search Results
- Check robots.txt allows indexing

### Debug Mode

Enable detailed logging:

```ruby
# In Rails console or initializer
Rails.logger.level = :debug

# Run job with detailed output
SeoAiEngine::OpportunityDiscoveryJob.perform_now
```

### Support Resources

- **Engine README**: `engines/seo_ai_engine/README.md`
- **Quickstart Guide**: `specs/006-ai-seo-engine/quickstart.md`
- **Task List**: `specs/006-ai-seo-engine/tasks.md`
- **Job Dashboard**: `http://localhost:3000/jobs`
- **Admin Dashboard**: `http://localhost:3000/seo_ai/admin`

---

**Last Updated**: 2025-11-16
**Version**: 1.0
**Status**: Production Ready
