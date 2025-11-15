# Feature Specification: AI SEO Engine

**Feature Branch**: `006-ai-seo-engine`
**Created**: 2025-11-15
**Status**: Draft
**Input**: User description: "AI-powered SEO content generation and optimization engine to replace £600/month agency with automated opportunity discovery, Claude-powered content generation, and performance tracking"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Discover High-Value SEO Opportunities (Priority: P1)

As a business owner, I need the system to automatically identify which content to create or optimize based on search data, so I can focus efforts on high-impact SEO opportunities without manual keyword research.

**Why this priority**: Core value proposition - without opportunity discovery, there's no direction for content generation. This is the foundation that justifies the entire system.

**Independent Test**: Can be fully tested by running the discovery process and verifying it produces a prioritized list of opportunities scored 0-100 based on search volume, competition, and business relevance.

**Acceptance Scenarios**:

1. **Given** the system has access to Google Search Console data, **When** daily discovery runs, **Then** opportunities are created for queries with 10+ impressions per month
2. **Given** the system has analyzed competitor SERPs via API, **When** scoring opportunities, **Then** each opportunity receives a score between 0-100 based on search volume (40pts), competition difficulty (30pts), product relevance (20pts), and content gap (10pts)
3. **Given** multiple opportunities exist, **When** viewing the dashboard, **Then** opportunities are sorted by score descending with high priority (70-100), medium (50-69), and low (0-49) clearly indicated
4. **Given** an opportunity is not relevant, **When** user dismisses it, **Then** it is removed from the active list and not shown again

---

### User Story 2 - Generate Content Drafts from Opportunities (Priority: P2)

As a business owner, I need AI to generate complete blog post drafts including product recommendations, so I can review and publish quality SEO content without writing it myself.

**Why this priority**: This delivers the cost savings vs the agency. Without content generation, the opportunity discovery alone doesn't reduce costs.

**Independent Test**: Can be fully tested by selecting a high-scoring opportunity and verifying the system produces a complete draft with title, body, meta tags, and natural product links ready for review.

**Acceptance Scenarios**:

1. **Given** a selected opportunity with target keyword "compostable coffee cups for cafes", **When** content generation is triggered, **Then** a content brief is created analyzing competitor content, suggested structure, and product linking strategy
2. **Given** a content brief exists, **When** the content writer generates a draft, **Then** the draft includes 1,500-2,000 words in markdown format with H2/H3 headers, natural product mentions, and SEO-optimized meta title and description
3. **Given** a draft is generated, **When** quality review runs, **Then** the draft receives a quality score (0-100) with specific review notes flagging any factual accuracy concerns, brand voice issues, or unnatural product mentions
4. **Given** the quality score is below 50, **When** review completes, **Then** the draft is not saved and an alert is sent to improve the generation prompts
5. **Given** a quality-approved draft exists, **When** user accesses the review interface, **Then** they can read the content, view quality notes, edit if needed, and approve or reject for publishing

---

### User Story 3 - Track Content Performance and ROI (Priority: P3)

As a business owner, I need to see how AI-generated content performs in search results and whether it delivers ROI, so I can justify the system cost vs the agency.

**Why this priority**: Validates the system's value but not needed until content is published. Performance tracking proves ROI over time but doesn't block initial value delivery.

**Independent Test**: Can be fully tested by publishing content, waiting one week, and verifying the system reports impressions, clicks, positions, and estimated traffic value from search console data.

**Acceptance Scenarios**:

1. **Given** content has been published for 7 days, **When** weekly performance tracking runs, **Then** the system records impressions, clicks, average position, and CTR from Google Search Console for target keywords
2. **Given** performance data exists for multiple weeks, **When** viewing the dashboard, **Then** week-over-week trends are displayed showing whether metrics are improving or declining
3. **Given** the system has monthly cost data (API usage) and traffic value estimates, **When** viewing ROI metrics, **Then** the dashboard shows total costs, estimated traffic value (clicks × £2 CPC), and net savings vs £600/month agency baseline
4. **Given** content has been published for 8+ weeks, **When** performance is below 50 impressions/week, **Then** it is flagged as an underperformer for potential refresh or optimization

---

### User Story 4 - Manage Monthly Budget and API Costs (Priority: P3)

As a business owner, I need the system to track and control API costs, so I don't accidentally overspend on content generation.

**Why this priority**: Important for cost control but not blocking core functionality. Budget tracking prevents runaway costs but the system can function without it initially.

**Independent Test**: Can be fully tested by generating content and verifying the system tracks Claude API costs, SerpAPI usage, and alerts when monthly budget thresholds are exceeded.

**Acceptance Scenarios**:

1. **Given** content generation uses Claude API, **When** each request completes, **Then** the cost (in GBP) is recorded in the budget tracking table
2. **Given** monthly API costs exceed £100, **When** the threshold is reached, **Then** an alert email is sent to the admin to investigate potential issues
3. **Given** the monthly budget is £90 (target operating cost), **When** costs approach £80, **Then** a warning notification is displayed in the dashboard
4. **Given** SerpAPI has a daily limit of 3 searches, **When** attempting a 4th search in one day, **Then** the request is queued for the next day and user is notified of the delay

---

### Edge Cases

- What happens when Google Search Console API returns no data (new site with no traffic)? System should display a message indicating insufficient data and suggest waiting until at least 100 impressions are recorded.
- What happens when SerpAPI is down or rate-limited? System should queue the opportunity analysis, retry with exponential backoff (max 3 attempts), and alert admin if all attempts fail.
- What happens when Claude generates content that's very similar to a competitor (potential plagiarism)? Quality reviewer should flag high similarity (>80% match), prevent draft from being saved, and alert for manual review.
- What happens when a user tries to generate content for a dismissed opportunity? System should warn that the opportunity was previously dismissed and ask for confirmation before proceeding.
- What happens when monthly API costs exceed £200 (double the expected cost)? System should automatically pause new content generation, send urgent alert to admin, and require manual review before resuming.
- What happens when no products match the opportunity topic? Content brief should flag this as "limited product relevance" and suggest informational content with general category links rather than specific product mentions.
- What happens when Google Search Console OAuth token expires? System should detect the auth failure, send email alert with re-authorization link, and pause opportunity discovery until reconnected.

## Requirements *(mandatory)*

### Functional Requirements

**Opportunity Discovery:**
- **FR-001**: System MUST fetch search performance data from Google Search Console API daily including queries, impressions, clicks, and average positions
- **FR-002**: System MUST fetch SERP analysis data from SerpAPI for target keywords including competitor URLs, positions, and page titles
- **FR-003**: System MUST score each opportunity 0-100 based on search volume (40%), competition difficulty (30%), product relevance (20%), and content gap (10%)
- **FR-004**: System MUST filter opportunities to only include queries with 10+ monthly impressions and exclude branded searches (queries containing company name)
- **FR-005**: System MUST categorize opportunities as "new_content" (create blog/guide), "optimize_existing" (improve existing page), or "quick_win" (position 11-20)
- **FR-006**: Users MUST be able to view, filter, sort, and dismiss opportunities from the dashboard

**Content Generation:**
- **FR-007**: System MUST create content briefs including target keyword, search intent, competitor analysis, suggested structure, and product linking strategy
- **FR-008**: System MUST generate content drafts of 1,500-2,000 words in markdown format with SEO-optimized headers, natural product mentions, and internal links
- **FR-009**: System MUST generate meta titles (50-60 characters) and meta descriptions (150-160 characters) for each content draft
- **FR-010**: System MUST perform quality review scoring each draft 0-100 and flagging factual accuracy concerns, brand voice issues, and unnatural product placement
- **FR-011**: System MUST NOT save drafts with quality scores below 50 and MUST alert for prompt improvement
- **FR-012**: Users MUST be able to review, edit, approve, or reject content drafts before publishing
- **FR-013**: System MUST validate that all product and category links in draft content resolve to existing entities

**Content Publishing:**
- **FR-014**: System MUST create published content items with unique slugs, SEO metadata, and relationships to products/categories
- **FR-015**: System MUST make published content accessible via public URLs (e.g., /blog/slug)
- **FR-016**: System MUST include published content in the sitemap with appropriate priority and change frequency
- **FR-017**: System MUST add Schema.org Article structured data to published content pages

**Performance Tracking:**
- **FR-018**: System MUST track weekly performance for each published content item including impressions, clicks, average position, and CTR from Google Search Console
- **FR-019**: System MUST calculate week-over-week trends for each performance metric
- **FR-020**: System MUST estimate traffic value using clicks multiplied by £2 CPC baseline
- **FR-021**: System MUST flag content as underperforming if published 8+ weeks ago with fewer than 50 impressions per week
- **FR-022**: System MUST display ROI metrics comparing monthly costs vs £600 agency baseline

**Cost Control:**
- **FR-023**: System MUST track API usage costs for each service (Claude, SerpAPI) in GBP per month
- **FR-024**: System MUST alert when monthly costs exceed £100 (investigation threshold)
- **FR-025**: System MUST warn when costs approach £80 (80% of £90 target budget)
- **FR-026**: System MUST enforce SerpAPI daily limit of 3 keyword searches, queueing excess requests for next day
- **FR-027**: System MUST enforce maximum 10 content drafts generated per week to prevent review queue overflow

**Error Handling:**
- **FR-028**: System MUST retry failed API requests with exponential backoff (max 3 attempts) before alerting admin
- **FR-029**: System MUST detect Google Search Console OAuth expiration and send re-authorization link via email
- **FR-030**: System MUST timeout Claude API requests after 120 seconds and queue for retry
- **FR-031**: System MUST check draft content for high similarity (>80%) to competitor content and block saving if detected

### Key Entities

- **Opportunity**: Represents a potential SEO opportunity discovered from search data. Attributes include target keyword, opportunity type, score (0-100), search volume, current position (if optimizing existing page), competition difficulty, target URL, metadata (competitor analysis, related keywords), status (pending/in_progress/completed/dismissed), and discovery timestamp.

- **Content Brief**: Represents the strategic plan created by the content strategist. Attributes include relationship to opportunity, target keyword, search intent (informational/commercial/navigational), suggested structure (H2s, sections, word count), competitor analysis, product linking strategy, internal linking strategy, AI model used, and generation cost.

- **Content Draft**: Represents AI-generated content awaiting review. Attributes include relationship to content brief, content type (blog_post/buying_guide/comparison), title, body (markdown), meta title, meta description, target keywords, status (pending_review/approved/rejected/published), quality score (0-100), review notes (flagged issues), reviewer model, generation cost, reviewed by user, and review timestamp.

- **Content Item**: Represents published content live on the site. Attributes include relationship to approved draft, unique slug, title, body, meta tags, target keywords, publication timestamp, author credit, header image, related products (IDs), related categories (IDs), and update timestamps.

- **Performance Snapshot**: Represents weekly search performance data for published content. Attributes include relationship to content item (or null for site-wide), period start/end dates, impressions, clicks, average position, CTR, keyword position breakdown, estimated traffic value (GBP), and snapshot timestamp.

- **Budget Tracking**: Represents monthly API cost tracking. Attributes include month, request counts (GSC, SerpAPI, LLM), costs by service (LLM, SerpAPI in GBP), total monthly cost, content pieces generated, and average cost per piece.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: System reduces SEO content costs by 85% (from £600/month agency to <£90/month operating costs)
- **SC-002**: Users can review and approve/reject content drafts in under 30 minutes per piece (vs 2-3 hours writing from scratch)
- **SC-003**: Generated content achieves average quality score of 70+ out of 100 on automated review
- **SC-004**: At least 20 blog posts published within first 3 months of operation
- **SC-005**: Published content generates 2,000+ monthly organic impressions within 6 months
- **SC-006**: Published content generates 300+ monthly organic clicks within 12 months (equivalent to £600 estimated traffic value, reaching breakeven)
- **SC-007**: System operates within £90/month budget target (£70-90 actual costs)
- **SC-008**: At least 3 published articles rank in top 10 search positions for target keywords within 6 months
- **SC-009**: Zero incidents of auto-publishing incorrect product information or unvetted content (100% manual approval compliance)
- **SC-010**: Cost per generated article averages £4-5 (vs £50-100 agency rate)
