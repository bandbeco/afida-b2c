# Quickstart: AI SEO Engine

**Feature**: 006-ai-seo-engine
**For**: Developers implementing the AI SEO Engine

## Prerequisites

- Rails 8.x application running
- PostgreSQL 14+
- Ruby 3.3.0+
- Access to: Google Search Console, SerpAPI account, Anthropic API key

## Setup Steps

### 1. Generate Rails Engine

```bash
cd /Users/laurentcurau/projects/shop
rails plugin new engines/seo_ai_engine --mountable --database=postgresql
```

### 2. Install Dependencies

Add to `engines/seo_ai_engine/seo_ai_engine.gemspec`:

```ruby
spec.add_dependency "ruby-llm", "~> 0.7"
spec.add_dependency "google-apis-webmasters_v3", "~> 0.20"
spec.add_dependency "googleauth", "~> 1.11"
spec.add_dependency "serpapi", "~> 2.2"
```

### 3. Configure API Credentials

```bash
rails credentials:edit
```

Add:

```yaml
seo_ai:
  google_oauth:
    client_id: YOUR_GOOGLE_CLIENT_ID
    client_secret: YOUR_GOOGLE_CLIENT_SECRET
    refresh_token: YOUR_REFRESH_TOKEN
  serpapi_key: YOUR_SERPAPI_KEY
  anthropic_key: YOUR_ANTHROPIC_KEY
```

### 4. Run Migrations

```bash
cd engines/seo_ai_engine
rails db:migrate
```

### 5. Mount Engine

In host app `config/routes.rb`:

```ruby
mount SeoAiEngine::Engine => "/seo_ai"

# Public blog routes
resources :blogs, only: [:index, :show], path: 'blog'
```

### 6. Configure Background Jobs

```bash
# Schedule daily opportunity discovery
# Add to config/schedule.yml (if using whenever gem)
opportunity_discovery:
  cron: "0 3 * * *"  # 3am daily
  class: "SeoAi::OpportunityDiscoveryJob"

performance_tracking:
  cron: "0 3 * * 0"  # 3am Sunday
  class: "SeoAi::PerformanceTrackingJob"
```

### 7. Access Admin Dashboard

Visit: `http://localhost:3000/seo_ai/admin/opportunities`

## Development Workflow

1. **Run tests**: `cd engines/seo_ai_engine && rails test`
2. **Start server**: `bin/dev` (from host app root)
3. **Trigger discovery**: `SeoAi::OpportunityDiscoveryJob.perform_now` (from Rails console)
4. **Generate content**: Click "Generate Content" on high-scoring opportunity in dashboard
5. **Review draft**: Visit `/seo_ai/admin/content_drafts`, click draft, approve
6. **View published**: Visit `/blog/:slug` to see published article

## Next Steps

- Read `data-model.md` for database schema details
- Read `research.md` for technology decisions
- Run `/speckit.tasks` to generate implementation tasks
