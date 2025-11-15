# Research: AI SEO Engine

**Date**: 2025-11-15
**Feature**: AI SEO Engine (006-ai-seo-engine)
**Purpose**: Resolve technical unknowns identified in plan.md Technical Context section

## Research Items

### 1. LLM Integration Gem Selection

**Question**: Should we use `ruby-llm` or `anthropic-rb` for Claude API integration?

**Decision**: Use `ruby-llm` gem

**Rationale**:
- **Provider flexibility**: `ruby-llm` provides unified interface across Claude, GPT-4, Gemini - allows easy experimentation with cheaper models for lower-priority tasks
- **Future-proofing**: If Anthropic pricing increases, can swap to OpenAI without code changes
- **Multi-model strategy**: Different content types could use different models (Claude Sonnet for writing, Haiku for review, GPT-4 for cost comparison)
- **Productization**: If engine becomes SaaS, customers can bring their own LLM API keys
- **Cost optimization**: A/B test quality vs cost across providers

**Alternatives Considered**:
- **anthropic-rb** (direct Anthropic client):
  - **Pros**: Direct access to Claude-specific features (prompt caching, extended thinking), one less abstraction layer
  - **Cons**: Vendor lock-in, can't easily test alternative LLMs, harder to optimize costs
  - **Rejected because**: Flexibility and cost optimization more important than Claude-specific features for this use case

**Implementation**:
```ruby
# Gemfile
gem 'ruby-llm'

# config/initializers/seo_ai.rb
SeoAi.configure do |config|
  config.llm_provider = :anthropic          # or :openai, :google
  config.strategist_model = "claude-sonnet-4-5"
  config.writer_model = "claude-sonnet-4-5"
  config.reviewer_model = "claude-haiku-4"  # Cheaper model for QA
end
```

---

### 2. Google Search Console API Client

**Question**: Which Ruby gem for Google Search Console API integration?

**Decision**: Use `google-apis-webmasters_v3` (official Google API client)

**Rationale**:
- **Official support**: Maintained by Google, guaranteed API compatibility
- **OAuth 2.0 built-in**: Handles OAuth flow and token refresh automatically
- **Comprehensive**: Covers all GSC API endpoints (search analytics, sitemaps, URL inspection)
- **Well-documented**: Google provides extensive documentation and examples
- **Battle-tested**: Used in production by thousands of Rails apps

**Alternatives Considered**:
- **google-search-console** (community gem):
  - **Pros**: Simpler API surface, easier to use
  - **Cons**: Less actively maintained, may lag behind API changes
  - **Rejected because**: Official gem more reliable for critical business functionality

- **Direct REST API calls** (HTTParty/Faraday):
  - **Pros**: No dependencies, full control
  - **Cons**: Manual OAuth implementation, brittle to API changes, more code to maintain
  - **Rejected because**: OAuth complexity and maintenance burden too high

**Implementation**:
```ruby
# Gemfile
gem 'google-apis-webmasters_v3'
gem 'googleauth'  # For OAuth 2.0

# app/services/seo_ai/gsc_client.rb
require 'google/apis/webmasters_v3'
require 'googleauth'

module SeoAi
  class GscClient
    def initialize
      @webmasters = Google::Apis::WebmastersV3::WebmastersService.new
      @webmasters.authorization = authorizer.get_credentials(user_id)
    end

    def search_analytics(start_date:, end_date:, dimensions: ['query'])
      # Fetch search performance data
    end
  end
end
```

**OAuth Setup**:
1. Enable Google Search Console API in Google Cloud Console
2. Create OAuth 2.0 credentials (Web application)
3. Store client_id, client_secret in Rails credentials
4. Implement OAuth flow in admin UI to get user consent
5. Store refresh token in encrypted credentials
6. Handle token expiration per FR-029

---

### 3. SerpAPI Client

**Question**: Which SerpAPI Ruby client to use?

**Decision**: Use `serpapi` official gem

**Rationale**:
- **Official client**: Maintained by SerpAPI team
- **Simple API**: Clean interface for Google search results
- **Rate limiting built-in**: Tracks API usage automatically
- **JSON response**: Easy to parse and extract competitor data
- **Well-documented**: Examples for Google search, organic results extraction

**Alternatives Considered**:
- **Direct HTTP requests** (HTTParty/Faraday):
  - **Pros**: No dependency
  - **Cons**: Manual parameter encoding, API changes require code updates
  - **Rejected because**: Official gem simplifies maintenance

**Implementation**:
```ruby
# Gemfile
gem 'serpapi'

# app/services/seo_ai/serp_client.rb
module SeoAi
  class SerpClient
    def initialize
      @client = GoogleSearch.new(api_key: SeoAi.config.serpapi_key)
    end

    def analyze_keyword(keyword)
      results = @client.get_hash(q: keyword, location: "United Kingdom")
      extract_competitors(results[:organic_results])
    end

    private

    def extract_competitors(organic_results)
      organic_results.first(10).map do |result|
        {
          url: result[:link],
          title: result[:title],
          snippet: result[:snippet],
          position: result[:position]
        }
      end
    end
  end
end
```

**Rate Limiting**:
- SerpAPI plan: 100 searches/month (£40-50)
- Daily limit: 3 searches/day (enforced in OpportunityDiscoveryJob)
- Queueing: Excess requests queued for next day (per FR-026)

---

### 4. Background Job Performance Goals

**Question**: What are the specific performance targets for background jobs?

**Decision**: Define job-specific SLAs

**Rationale**:
- Background jobs have different characteristics than web requests
- SLAs should align with business requirements (daily discovery, weekly reporting)
- Timeouts prevent runaway jobs from consuming resources

**Performance Targets**:

| Job | Frequency | Timeout | Expected Duration | Max Retries |
|-----|-----------|---------|-------------------|-------------|
| OpportunityDiscoveryJob | Daily (3am) | 30 minutes | 5-10 minutes | 3 |
| ContentGenerationJob | On-demand | 10 minutes | 3-5 minutes | 3 |
| PerformanceTrackingJob | Weekly (Sunday 3am) | 20 minutes | 5-10 minutes | 3 |

**Detailed Breakdown**:

**OpportunityDiscoveryJob** (Daily):
- Fetch GSC data (last 28 days): ~30 seconds
- Fetch SerpAPI for 3 keywords: ~10 seconds (3× ~3s each)
- Score opportunities: ~1 minute (SQL bulk operations)
- Total: ~2 minutes typical, 30min timeout for safety

**ContentGenerationJob** (On-demand):
- ContentStrategist (brief creation): ~30 seconds (Claude API ~20s)
- ContentWriter (1,500-2,000 words): ~120 seconds (Claude API ~90-120s)
- ContentReviewer (quality check): ~30 seconds (Claude API ~20s)
- Total: ~3 minutes typical, 10min timeout

**PerformanceTrackingJob** (Weekly):
- Fetch GSC data for each published article: ~10 seconds per article
- Calculate trends and metrics: ~10 seconds
- Total: ~3 minutes for 10 articles, 20min timeout

**Monitoring**:
- Sidekiq dashboard tracks job duration and failures
- Alert if job exceeds 80% of timeout (early warning)
- Daily Slack notification with job statistics

---

### 5. API Timeout and Retry Strategy

**Question**: What are the specific timeout and retry configurations for external APIs?

**Decision**: Per-API timeout and exponential backoff strategy

**Rationale**:
- Different APIs have different latency characteristics
- Exponential backoff prevents API rate limit violations
- Max retries prevent infinite loops
- Circuit breaker pattern for sustained failures

**Timeout Configuration**:

| API | Timeout | Max Retries | Backoff | Circuit Breaker |
|-----|---------|-------------|---------|-----------------|
| Claude (ruby-llm) | 120s | 3 | Exponential (2s, 4s, 8s) | 5 failures → 15min pause |
| Google Search Console | 30s | 3 | Exponential (1s, 2s, 4s) | 10 failures → 1hr pause |
| SerpAPI | 10s | 3 | Exponential (1s, 2s, 4s) | N/A (rate limit enforced) |

**Implementation**:

```ruby
# app/services/seo_ai/llm_client.rb
module SeoAi
  class LlmClient
    MAX_RETRIES = 3
    TIMEOUT = 120 # seconds
    BACKOFF_BASE = 2 # seconds

    def generate(prompt:, model:)
      attempts = 0
      begin
        attempts += 1
        Timeout.timeout(TIMEOUT) do
          client.chat(messages: [{ role: "user", content: prompt }], model: model)
        end
      rescue Timeout::Error, LLMError => e
        if attempts < MAX_RETRIES
          backoff_time = BACKOFF_BASE ** attempts
          sleep(backoff_time)
          retry
        else
          # Log error, alert admin, return nil
          Rails.logger.error("LLM API failed after #{MAX_RETRIES} attempts: #{e.message}")
          SeoAi::AlertMailer.api_failure(service: "Claude", error: e).deliver_later
          nil
        end
      end
    end
  end
end
```

**Circuit Breaker**:
- Track failures in Redis (key: `seo_ai:circuit_breaker:claude`, TTL: 1 hour)
- If 5 consecutive failures → Open circuit for 15 minutes
- During open circuit → Fail fast, don't attempt API calls
- After 15 minutes → Half-open (allow 1 test request)
- If test succeeds → Close circuit (normal operation)

---

## Summary

All NEEDS CLARIFICATION items resolved:

1. ✅ **LLM Integration**: `ruby-llm` gem for provider flexibility and cost optimization
2. ✅ **Google Search Console**: `google-apis-webmasters_v3` official gem with OAuth 2.0
3. ✅ **SerpAPI**: `serpapi` official gem, 3 searches/day limit enforced
4. ✅ **Job Performance**: Specific SLAs per job (2-10min typical, 10-30min timeout)
5. ✅ **API Timeouts**: Per-API timeouts (10-120s), exponential backoff, circuit breaker pattern

**Next Phase**: Proceed to Phase 1 (data-model.md, contracts/, quickstart.md)
