# Data Model: AI SEO Engine

**Date**: 2025-11-15
**Feature**: 006-ai-seo-engine
**Database**: PostgreSQL 14+
**Namespace**: `seo_ai_*` tables (engine-owned)

## Entity Relationship Diagram

```
┌─────────────────────┐
│ seo_ai_opportunities│
└──────────┬──────────┘
           │ 1
           │
           │ has_one
           │
           ▼ 1
┌─────────────────────────┐
│ seo_ai_content_briefs   │
└──────────┬──────────────┘
           │ 1
           │
           │ has_one
           │
           ▼ 1
┌─────────────────────────┐      ┌────────────────┐
│ seo_ai_content_drafts   │──┬──▶│ products       │ (host app)
└──────────┬──────────────┘  │   └────────────────┘
           │ 1                │   ┌────────────────┐
           │                  └──▶│ categories     │ (host app)
           │ has_one              └────────────────┘
           │                      ┌────────────────┐
           ▼ 1                    │ users          │ (host app)
┌─────────────────────────┐      └────────────────┘
│ seo_ai_content_items    │             ▲
└──────────┬──────────────┘             │
           │ 1                           │ reviewed_by
           │                             │
           │ has_many            ┌───────┴────────────┐
           │                     │ seo_ai_content_    │
           ▼ *                   │     drafts         │
┌─────────────────────────────┐ └────────────────────┘
│ seo_ai_performance_snapshots│
└─────────────────────────────┘

┌─────────────────────────────┐
│ seo_ai_budget_tracking      │ (independent, monthly aggregates)
└─────────────────────────────┘
```

## Tables

### 1. seo_ai_opportunities

**Purpose**: Discovered SEO opportunities from Google Search Console + SerpAPI analysis

**Columns**:
```ruby
create_table :seo_ai_opportunities do |t|
  t.string :keyword, null: false, index: true                    # Target keyword (e.g., "compostable coffee cups")
  t.string :opportunity_type, null: false, index: true           # Enum: new_content, optimize_existing, quick_win
  t.integer :score, null: false, index: true                     # 0-100 (scoring algorithm result)
  t.integer :search_volume                                       # Monthly search volume from SerpAPI
  t.integer :current_position                                    # Current ranking (if optimize_existing/quick_win)
  t.string :competition_difficulty                               # Enum: low, medium, high
  t.string :target_url                                           # Existing page URL (if optimize_existing)
  t.jsonb :metadata, default: {}                                 # {competitor_urls: [], related_keywords: [], search_intent: ""}
  t.string :status, null: false, default: "pending", index: true # Enum: pending, in_progress, completed, dismissed
  t.datetime :discovered_at, null: false, index: true            # When opportunity was identified

  t.timestamps
end

add_index :seo_ai_opportunities, [:status, :score]               # Filter by status + sort by score
add_index :seo_ai_opportunities, :keyword, unique: true          # Prevent duplicate opportunities for same keyword
```

**Validations**:
```ruby
validates :keyword, presence: true, uniqueness: true
validates :opportunity_type, inclusion: { in: %w[new_content optimize_existing quick_win] }
validates :score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
validates :competition_difficulty, inclusion: { in: %w[low medium high] }, allow_nil: true
validates :status, inclusion: { in: %w[pending in_progress completed dismissed] }
validates :discovered_at, presence: true
```

**Scopes**:
```ruby
scope :high_priority, -> { where(score: 70..100) }
scope :medium_priority, -> { where(score: 50..69) }
scope :pending, -> { where(status: "pending") }
scope :recent, -> { order(discovered_at: :desc) }
```

---

### 2. seo_ai_content_briefs

**Purpose**: Strategic content plans created by ContentStrategist (Phase 1 of content generation)

**Columns**:
```ruby
create_table :seo_ai_content_briefs do |t|
  t.references :opportunity, null: false, foreign_key: { to_table: :seo_ai_opportunities }, index: true
  t.string :target_keyword, null: false                          # Copied from opportunity for convenience
  t.string :search_intent                                        # Enum: informational, commercial, navigational
  t.jsonb :suggested_structure, default: {}                      # {word_count: 1500, h2_headings: [], sections: []}
  t.jsonb :competitor_analysis, default: {}                      # {top_3_urls: [], content_gaps: [], strengths: []}
  t.jsonb :product_links, default: {}                            # {product_ids: [1, 5, 12], strategy: "natural mentions"}
  t.jsonb :internal_links, default: {}                           # {category_ids: [2], related_articles: []}
  t.string :created_by_model                                     # LLM model used (e.g., "claude-sonnet-4-5")
  t.decimal :generation_cost_gbp, precision: 10, scale: 4        # API cost for brief creation

  t.timestamps
end

add_index :seo_ai_content_briefs, :opportunity_id, unique: true  # One brief per opportunity
```

**Validations**:
```ruby
validates :opportunity, presence: true
validates :target_keyword, presence: true
validates :search_intent, inclusion: { in: %w[informational commercial navigational] }, allow_nil: true
validates :created_by_model, presence: true
validates :generation_cost_gbp, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
```

---

### 3. seo_ai_content_drafts

**Purpose**: AI-generated content drafts awaiting human review (Phase 2 & 3 of content generation)

**Columns**:
```ruby
create_table :seo_ai_content_drafts do |t|
  t.references :content_brief, null: false, foreign_key: { to_table: :seo_ai_content_briefs }, index: true
  t.string :content_type, null: false                            # Enum: blog_post, buying_guide, comparison
  t.string :title, null: false                                   # Generated article title
  t.text :body, null: false                                      # Markdown content (1,500-2,000 words)
  t.string :meta_title                                           # SEO meta title (50-60 chars)
  t.string :meta_description                                     # SEO meta description (150-160 chars)
  t.string :target_keywords, array: true, default: []            # Array of keywords to target
  t.string :status, null: false, default: "pending_review"       # Enum: pending_review, approved, rejected, published
  t.integer :quality_score                                       # 0-100 from ContentReviewer
  t.jsonb :review_notes, default: {}                             # {concerns: [], suggestions: [], flags: []}
  t.string :reviewer_model                                       # LLM model for review (e.g., "claude-haiku-4")
  t.decimal :generation_cost_gbp, precision: 10, scale: 4        # API cost for draft + review
  t.references :reviewed_by, foreign_key: { to_table: :users }  # User who approved/rejected
  t.datetime :reviewed_at                                        # When human reviewed

  t.timestamps
end

add_index :seo_ai_content_drafts, [:status, :quality_score]
add_index :seo_ai_content_drafts, :content_brief_id, unique: true  # One draft per brief
```

**Validations**:
```ruby
validates :content_brief, presence: true
validates :content_type, inclusion: { in: %w[blog_post buying_guide comparison] }
validates :title, presence: true
validates :body, presence: true, length: { minimum: 1000 }      # Minimum 1000 chars (~150-200 words)
validates :meta_title, length: { maximum: 60 }, allow_blank: true
validates :meta_description, length: { maximum: 160 }, allow_blank: true
validates :status, inclusion: { in: %w[pending_review approved rejected published] }
validates :quality_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
validate :quality_score_threshold                               # Must be >=50 to save (FR-011)

def quality_score_threshold
  if quality_score.present? && quality_score < 50
    errors.add(:quality_score, "must be at least 50 to save draft")
  end
end
```

**Scopes**:
```ruby
scope :pending_review, -> { where(status: "pending_review") }
scope :approved, -> { where(status: "approved") }
scope :high_quality, -> { where("quality_score >= ?", 70) }
```

---

### 4. seo_ai_content_items

**Purpose**: Published blog posts/guides visible to public (created from approved drafts)

**Columns**:
```ruby
create_table :seo_ai_content_items do |t|
  t.references :content_draft, null: false, foreign_key: { to_table: :seo_ai_content_drafts }
  t.string :slug, null: false, index: { unique: true }           # SEO-friendly URL slug
  t.string :title, null: false                                   # Published title
  t.text :body, null: false                                      # Published markdown body
  t.string :meta_title                                           # Published meta title
  t.string :meta_description                                     # Published meta description
  t.string :target_keywords, array: true, default: []            # Published target keywords
  t.datetime :published_at, null: false, index: true             # Publication timestamp
  t.string :author_credit, default: "Afida Editorial Team"       # Byline
  t.integer :related_product_ids, array: true, default: []       # Products mentioned (IDs from host app)
  t.integer :related_category_ids, array: true, default: []      # Categories mentioned (IDs from host app)

  t.timestamps
end

add_index :seo_ai_content_items, :published_at                   # Recent posts query
```

**Validations**:
```ruby
validates :content_draft, presence: true
validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
validates :title, presence: true
validates :body, presence: true
validates :published_at, presence: true
```

**Methods**:
```ruby
def to_param
  slug  # Use slug in URLs instead of ID
end
```

---

### 5. seo_ai_performance_snapshots

**Purpose**: Weekly search performance tracking for published content (from Google Search Console)

**Columns**:
```ruby
create_table :seo_ai_performance_snapshots do |t|
  t.references :content_item, foreign_key: { to_table: :seo_ai_content_items }, index: true # null = site-wide snapshot
  t.date :period_start, null: false                              # Start of reporting week
  t.date :period_end, null: false                                # End of reporting week
  t.integer :impressions, default: 0                             # Total impressions from GSC
  t.integer :clicks, default: 0                                  # Total clicks from GSC
  t.decimal :avg_position, precision: 5, scale: 2               # Average search position
  t.decimal :ctr, precision: 5, scale: 4                         # Click-through rate (clicks/impressions)
  t.jsonb :keyword_positions, default: {}                        # {keyword1: position, keyword2: position}
  t.decimal :traffic_value_gbp, precision: 10, scale: 2         # Estimated value (clicks × £2 CPC)

  t.timestamps
end

add_index :seo_ai_performance_snapshots, [:content_item_id, :period_end]
add_index :seo_ai_performance_snapshots, :period_end              # Weekly queries
```

**Validations**:
```ruby
validates :period_start, :period_end, presence: true
validates :impressions, :clicks, numericality: { greater_than_or_equal_to: 0 }
validates :avg_position, numericality: { greater_than: 0 }, allow_nil: true
validates :ctr, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
validates :traffic_value_gbp, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
validate :period_end_after_start

def period_end_after_start
  if period_end && period_start && period_end < period_start
    errors.add(:period_end, "must be after period_start")
  end
end
```

**Scopes**:
```ruby
scope :for_period, ->(start_date, end_date) { where(period_start: start_date..end_date) }
scope :recent_weeks, ->(count) { order(period_end: :desc).limit(count) }
scope :site_wide, -> { where(content_item_id: nil) }
```

---

### 6. seo_ai_budget_tracking

**Purpose**: Monthly API cost tracking and budget monitoring

**Columns**:
```ruby
create_table :seo_ai_budget_tracking do |t|
  t.date :month, null: false, index: { unique: true }            # Month being tracked (first day of month)
  t.integer :gsc_requests, default: 0                            # Google Search Console API requests
  t.integer :serpapi_requests, default: 0                        # SerpAPI requests
  t.integer :llm_requests, default: 0                            # LLM API requests (Claude)
  t.decimal :llm_cost_gbp, precision: 10, scale: 2, default: 0  # Total LLM costs
  t.decimal :serpapi_cost_gbp, precision: 10, scale: 2, default: 0  # Total SerpAPI costs
  t.decimal :total_cost_gbp, precision: 10, scale: 2, default: 0    # Sum of all costs
  t.integer :content_pieces_generated, default: 0               # Number of drafts created
  t.decimal :avg_cost_per_piece, precision: 10, scale: 2        # total_cost / content_pieces

  t.timestamps
end
```

**Validations**:
```ruby
validates :month, presence: true, uniqueness: true
validates :gsc_requests, :serpapi_requests, :llm_requests, :content_pieces_generated,
          numericality: { greater_than_or_equal_to: 0 }
validates :llm_cost_gbp, :serpapi_cost_gbp, :total_cost_gbp, :avg_cost_per_piece,
          numericality: { greater_than_or_equal_to: 0 }
```

**Methods**:
```ruby
def calculate_totals
  self.total_cost_gbp = llm_cost_gbp + serpapi_cost_gbp
  self.avg_cost_per_piece = content_pieces_generated > 0 ? total_cost_gbp / content_pieces_generated : 0
end

before_save :calculate_totals
```

---

## Indexes Summary

**Primary Indexes** (created by references/foreign_key):
- `seo_ai_content_briefs.opportunity_id`
- `seo_ai_content_drafts.content_brief_id`
- `seo_ai_content_drafts.reviewed_by_id`
- `seo_ai_content_items.content_draft_id`
- `seo_ai_performance_snapshots.content_item_id`

**Additional Indexes** (performance optimization):
- `seo_ai_opportunities`: keyword (unique), opportunity_type, score, status, discovered_at, [status, score]
- `seo_ai_content_briefs`: opportunity_id (unique)
- `seo_ai_content_drafts`: content_brief_id (unique), [status, quality_score]
- `seo_ai_content_items`: slug (unique), published_at
- `seo_ai_performance_snapshots`: [content_item_id, period_end], period_end
- `seo_ai_budget_tracking`: month (unique)

---

## State Transitions

### Opportunity Lifecycle
```
┌─────────┐
│ pending │ (newly discovered)
└────┬────┘
     │
     ├──▶ in_progress (content generation started)
     │
     ├──▶ completed (content published)
     │
     └──▶ dismissed (not relevant)
```

### Draft Lifecycle
```
┌────────────────┐
│ pending_review │ (generated, awaiting human review)
└───────┬────────┘
        │
        ├──▶ approved (user approved, ready to publish)
        │
        ├──▶ rejected (user rejected, back to opportunity)
        │
        └──▶ published (converted to ContentItem)
```

---

## Data Retention

- **Opportunities**: Keep indefinitely (historical record of discovered keywords)
- **Content Briefs**: Keep indefinitely (reference for future similar content)
- **Content Drafts**: Keep for 6 months after rejection, indefinitely if approved/published
- **Content Items**: Keep indefinitely (published content)
- **Performance Snapshots**: Keep 2 years (performance history)
- **Budget Tracking**: Keep indefinitely (financial records)

---

## Migration Order

Migrations must be run in dependency order:

1. `001_create_seo_ai_opportunities.rb`
2. `002_create_seo_ai_content_briefs.rb` (depends on opportunities)
3. `003_create_seo_ai_content_drafts.rb` (depends on content_briefs, users)
4. `004_create_seo_ai_content_items.rb` (depends on content_drafts)
5. `005_create_seo_ai_performance_snapshots.rb` (depends on content_items)
6. `006_create_seo_ai_budget_tracking.rb` (independent)

---

## Next Steps

- **Phase 1 Continued**: Generate API contracts (admin dashboard endpoints)
- **Phase 1 Continued**: Generate quickstart.md (developer setup guide)
- **Phase 1 Continued**: Update agent context with new technologies
