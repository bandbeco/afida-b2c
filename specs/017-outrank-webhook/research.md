# Research: Outrank Webhook Integration

**Feature**: 017-outrank-webhook
**Date**: 2026-01-14
**Status**: Complete

## Research Summary

All technical decisions have been resolved using Outrank's official webhook documentation. No unknowns remain.

---

## 1. Webhook Payload Structure

**Decision**: Use Outrank's documented payload structure with `event_type`, `timestamp`, and `data.articles[]` array.

**Rationale**: Outrank's documentation clearly specifies the payload format. The structure supports batch processing of multiple articles in a single request.

**Alternatives Considered**:
- N/A - payload structure is defined by Outrank, not a choice

**Documentation Source**: Outrank Webhook Integration Docs (dashboard/integrations/docs/webhook)

---

## 2. Authentication Method

**Decision**: Bearer token in Authorization header

**Rationale**: Outrank requires `Authorization: Bearer {token}` format. This is simpler than HMAC signature verification and matches their documented approach.

**Alternatives Considered**:
- HMAC signature verification - Not supported by Outrank
- API key in query parameter - Not supported; less secure
- API key in custom header - Not the documented approach

**Implementation**:
```ruby
def verify_access_token
  auth_header = request.headers["Authorization"]
  return head :unauthorized unless auth_header&.start_with?("Bearer ")

  token = auth_header.split(" ").last
  return head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(
    token,
    Rails.application.credentials.dig(:outrank, :access_token)
  )
end
```

---

## 3. Content Format

**Decision**: Use `content_markdown` field directly (no HTML conversion needed)

**Rationale**: Outrank provides both `content_markdown` and `content_html`. Since BlogPost stores Markdown, we use the Markdown field directly, eliminating conversion complexity.

**Alternatives Considered**:
- Convert `content_html` to Markdown - Unnecessary; Markdown already provided
- Store HTML and convert on display - Inconsistent with existing BlogPost model

**Impact**: No additional gem dependencies required. Simplifies implementation.

---

## 4. Idempotency Strategy

**Decision**: Store Outrank's `id` field in new `outrank_id` column; skip or update existing articles

**Rationale**: Outrank may retry webhook deliveries. Using their unique ID ensures duplicate requests don't create duplicate posts.

**Alternatives Considered**:
- Use `slug` for deduplication - Slugs could legitimately change; not unique identifier
- No deduplication (accept duplicates) - Data integrity issues
- Hash-based deduplication - Unnecessary complexity when unique ID provided

**Implementation**:
```ruby
# Migration
add_column :blog_posts, :outrank_id, :string
add_index :blog_posts, :outrank_id, unique: true

# Service
existing = BlogPost.find_by(outrank_id: article_data["id"])
if existing
  Rails.logger.info "Skipping duplicate article: #{article_data['id']}"
  return existing
end
```

---

## 5. Category Mapping

**Decision**: Use first tag from `tags[]` array to find or create BlogCategory

**Rationale**: Outrank provides tags but no explicit category field. First tag is the most relevant categorization.

**Alternatives Considered**:
- Create category for each tag - Would create many categories; complicates organization
- Ignore tags entirely - Loses valuable categorization data
- Use all tags as comma-separated field - BlogPost uses single category association

**Implementation**:
```ruby
def find_or_create_category(tags)
  return nil if tags.blank?

  category_name = tags.first
  BlogCategory.find_or_create_by!(name: category_name) do |cat|
    cat.slug = category_name.parameterize
  end
end
```

---

## 6. Image Download Strategy

**Decision**: Download `image_url` synchronously with timeout; attach via Active Storage; graceful failure

**Rationale**: Cover images should be hosted on Afida infrastructure. Synchronous download keeps webhook processing simple. Timeout prevents hanging on slow image servers.

**Alternatives Considered**:
- Background job for image download - Adds complexity; webhook response delayed anyway
- Store external URL only - External dependency; images could disappear
- Skip images entirely - Loses visual content

**Implementation**:
```ruby
def download_cover_image(blog_post, image_url)
  return if image_url.blank?

  response = HTTP.timeout(10).get(image_url)
  return unless response.status.success?

  filename = File.basename(URI.parse(image_url).path)
  blog_post.cover_image.attach(
    io: StringIO.new(response.body.to_s),
    filename: filename,
    content_type: response.content_type.mime_type
  )
rescue HTTP::Error, URI::Error => e
  Rails.logger.warn "Failed to download cover image: #{e.message}"
  # Continue without image - article still created
end
```

**Dependency**: Add `http` gem for cleaner HTTP requests with timeout support.

---

## 7. Excerpt Generation

**Decision**: Extract first paragraph from `content_markdown` if excerpt not provided

**Rationale**: BlogPost has an optional excerpt field. Outrank doesn't provide excerpts, so we generate one from content.

**Implementation**:
```ruby
def extract_excerpt(content_markdown)
  return nil if content_markdown.blank?

  # Find first non-empty paragraph (skip headings starting with #)
  paragraphs = content_markdown.split(/\n\n+/)
  first_para = paragraphs.find { |p| p.present? && !p.start_with?("#") }

  # Strip markdown formatting and truncate
  plain_text = first_para&.gsub(/[#*_\[\]()>`]/, "")&.strip
  plain_text&.truncate(160)
end
```

---

## 8. Batch Processing

**Decision**: Process all articles in `data.articles[]`; return aggregate success/failure response

**Rationale**: Outrank can send multiple articles per webhook. Each article should be processed independently so one failure doesn't block others.

**Implementation**:
```ruby
def process_webhook(payload)
  results = payload.dig("data", "articles").map do |article_data|
    begin
      { id: article_data["id"], status: "success", blog_post_id: import_article(article_data).id }
    rescue => e
      Rails.logger.error "Failed to import article #{article_data['id']}: #{e.message}"
      { id: article_data["id"], status: "error", message: e.message }
    end
  end

  { processed: results.count, results: results }
end
```

---

## Dependencies to Add

| Gem | Purpose | Version |
|-----|---------|---------|
| `http` | HTTP client with timeout support for image downloads | ~> 5.0 |

---

## Research Complete

All technical decisions documented. Ready for Phase 1: Design & Contracts.
