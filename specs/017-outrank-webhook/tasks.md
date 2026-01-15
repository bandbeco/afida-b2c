# Tasks: Outrank Webhook Integration

**Feature**: 017-outrank-webhook
**Generated**: 2026-01-15
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Overview

Implementation tasks organized by user story priority. Each task follows test-first development (constitution requirement).

---

## Phase 0: Setup & Foundation

### T0.1: Create migration for outrank_id column
**Priority**: P0 (Blocking)
**Dependencies**: None
**Files**: `db/migrate/xxx_add_outrank_id_to_blog_posts.rb`

Create migration to add `outrank_id` column to `blog_posts` table with unique index.

```ruby
class AddOutrankIdToBlogPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :blog_posts, :outrank_id, :string
    add_index :blog_posts, :outrank_id, unique: true
  end
end
```

**Acceptance**:
- [x] Migration creates `outrank_id` string column
- [x] Unique index added on `outrank_id`
- [x] `rails db:migrate` runs without errors

---

### T0.2: Add http gem dependency
**Priority**: P0 (Blocking)
**Dependencies**: None
**Files**: `Gemfile`, `Gemfile.lock`

Add `http` gem for HTTP client with timeout support (used for image downloads).

```bash
bundle add http
```

**Acceptance**:
- [x] `http` gem added to Gemfile
- [x] `bundle install` succeeds

---

### T0.3: Add webhook route
**Priority**: P0 (Blocking)
**Dependencies**: None
**Files**: `config/routes.rb`

Add route for webhook endpoint under `/api/webhooks/outrank`.

**Acceptance**:
- [x] `POST /api/webhooks/outrank` route exists
- [x] Route maps to `Api::Webhooks::OutrankController#create`

---

### T0.4: Update BlogPost model
**Priority**: P0 (Blocking)
**Dependencies**: T0.1
**Files**: `app/models/blog_post.rb`

Add `outrank_id` to model (no validation changes needed, just ensure attr accessible).

**Acceptance**:
- [x] `outrank_id` is accessible
- [x] Existing validations unchanged

---

### T0.5: Add test fixtures
**Priority**: P0 (Blocking)
**Dependencies**: T0.1
**Files**: `test/fixtures/blog_posts.yml`

Add fixtures for outrank-imported posts and duplicate testing.

**Acceptance**:
- [x] `outrank_imported` fixture exists with `outrank_id`
- [x] `duplicate_outrank` fixture exists for duplicate testing

---

## Phase 1: US2 - Secure Webhook Authentication (P1)

*Authentication must be implemented first as it's a prerequisite for all other functionality.*

### T1.1: Test - Authentication rejects missing token
**Priority**: P1
**Dependencies**: T0.3
**Files**: `test/controllers/api/webhooks/outrank_controller_test.rb`

Write test that verifies requests without Authorization header return 401.

**Test Scenario**:
```ruby
test "returns 401 when Authorization header is missing" do
  post api_webhooks_outrank_url, params: valid_payload, as: :json
  assert_response :unauthorized
end
```

**Acceptance**:
- [x] Test exists and initially fails
- [x] Test asserts 401 response
- [x] Test asserts no BlogPost created

---

### T1.2: Test - Authentication rejects invalid token
**Priority**: P1
**Dependencies**: T0.3
**Files**: `test/controllers/api/webhooks/outrank_controller_test.rb`

Write test that verifies requests with wrong token return 401.

**Test Scenario**:
```ruby
test "returns 401 when token is invalid" do
  post api_webhooks_outrank_url,
       params: valid_payload,
       headers: { "Authorization" => "Bearer wrong-token" },
       as: :json
  assert_response :unauthorized
end
```

**Acceptance**:
- [x] Test exists and initially fails
- [x] Test asserts 401 response
- [x] Test asserts no BlogPost created

---

### T1.3: Test - Authentication accepts valid token
**Priority**: P1
**Dependencies**: T0.3
**Files**: `test/controllers/api/webhooks/outrank_controller_test.rb`

Write test that verifies requests with valid Bearer token are processed.

**Test Scenario**:
```ruby
test "processes request when token is valid" do
  post api_webhooks_outrank_url,
       params: valid_payload,
       headers: valid_auth_header,
       as: :json
  assert_response :success
end
```

**Acceptance**:
- [x] Test exists and initially fails
- [x] Test uses stubbed credentials token
- [x] Test asserts 200 response

---

### T1.4: Implement controller with authentication
**Priority**: P1
**Dependencies**: T1.1, T1.2, T1.3
**Files**: `app/controllers/api/webhooks/outrank_controller.rb`

Create controller with Bearer token authentication using `before_action`.

```ruby
module Api
  module Webhooks
    class OutrankController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :verify_access_token

      def create
        # Placeholder - will be implemented in T2.x
        head :ok
      end

      private

      def verify_access_token
        # Implementation here
      end
    end
  end
end
```

**Acceptance**:
- [x] All T1.x tests pass
- [x] Uses `secure_compare` for timing-safe comparison
- [x] Token read from `Rails.application.credentials.dig(:outrank, :access_token)`
- [x] Returns JSON error response on 401

---

## Phase 2: US1 - Automatic Article Ingestion (P1)

*Core functionality - creating BlogPosts from webhook payloads.*

### T2.1: Test - Creates BlogPost from valid payload
**Priority**: P1
**Dependencies**: T1.4, T0.5
**Files**: `test/services/outrank/article_importer_test.rb`

Write test for the ArticleImporter service creating a BlogPost.

**Test Scenario**:
```ruby
test "creates blog post from article data" do
  article_data = {
    "id" => "new-article-123",
    "title" => "Test Article",
    "slug" => "test-article",
    "content_markdown" => "# Hello World",
    "meta_description" => "Test description"
  }

  assert_difference "BlogPost.count", 1 do
    Outrank::ArticleImporter.new(article_data).call
  end

  post = BlogPost.last
  assert_equal "Test Article", post.title
  assert_equal "test-article", post.slug
  assert_equal "# Hello World", post.body
end
```

**Acceptance**:
- [x] Test exists and initially fails
- [x] Verifies all field mappings

---

### T2.2: Test - Maps first tag to BlogCategory
**Priority**: P1
**Dependencies**: T2.1
**Files**: `test/services/outrank/article_importer_test.rb`

Write test that first tag creates or finds a BlogCategory.

**Test Scenario**:
```ruby
test "uses first tag as blog category" do
  article_data = valid_article_data.merge("tags" => ["sustainability", "cafes"])

  importer = Outrank::ArticleImporter.new(article_data)
  importer.call

  post = BlogPost.last
  assert_equal "sustainability", post.blog_category.name
end
```

**Acceptance**:
- [x] Test exists and initially fails
- [x] Verifies category association
- [x] Verifies category created if not exists

---

### T2.3: Test - Creates post as unpublished draft
**Priority**: P1
**Dependencies**: T2.1
**Files**: `test/services/outrank/article_importer_test.rb`

Write test that BlogPost is created with `published: false`.

**Acceptance**:
- [x] Test exists and initially fails
- [x] Verifies `published: false`
- [x] Verifies `published_at: nil`

---

### T2.4: Implement ArticleImporter service
**Priority**: P1
**Dependencies**: T2.1, T2.2, T2.3
**Files**: `app/services/outrank/article_importer.rb`

Create service that maps Outrank article data to BlogPost attributes.

**Acceptance**:
- [x] All T2.1-T2.3 tests pass
- [x] Field mapping matches data-model.md
- [x] Stores `outrank_id` from Outrank's `id`
- [x] Extracts excerpt from content if not provided

---

### T2.5: Test - WebhookProcessor handles batch of articles
**Priority**: P1
**Dependencies**: T2.4
**Files**: `test/services/outrank/webhook_processor_test.rb`

Write test for processing multiple articles in one webhook.

**Test Scenario**:
```ruby
test "processes multiple articles in batch" do
  payload = {
    "event_type" => "publish_articles",
    "data" => {
      "articles" => [article_1, article_2, article_3]
    }
  }

  assert_difference "BlogPost.count", 3 do
    Outrank::WebhookProcessor.new(payload).call
  end
end
```

**Acceptance**:
- [x] Test exists and initially fails
- [x] Verifies all articles processed
- [x] Returns aggregate results

---

### T2.6: Implement WebhookProcessor service
**Priority**: P1
**Dependencies**: T2.4, T2.5
**Files**: `app/services/outrank/webhook_processor.rb`

Create orchestrating service that processes webhook payloads.

**Acceptance**:
- [x] All T2.5 tests pass
- [x] Iterates over `data.articles[]`
- [x] Returns results for each article
- [x] Handles partial failures gracefully

---

### T2.7: Integrate processor into controller
**Priority**: P1
**Dependencies**: T2.6
**Files**: `app/controllers/api/webhooks/outrank_controller.rb`

Update controller to use WebhookProcessor and return proper response.

**Acceptance**:
- [x] Controller delegates to WebhookProcessor
- [x] Returns JSON response per API contract
- [x] Full integration test passes

---

## Phase 3: US3 - Duplicate Article Handling (P2)

*Idempotency via outrank_id.*

### T3.1: Test - Skips duplicate articles
**Priority**: P2
**Dependencies**: T2.4, T0.5
**Files**: `test/services/outrank/article_importer_test.rb`

Write test that duplicate `outrank_id` is skipped.

**Test Scenario**:
```ruby
test "skips article when outrank_id already exists" do
  existing = blog_posts(:outrank_imported)
  article_data = valid_article_data.merge("id" => existing.outrank_id)

  assert_no_difference "BlogPost.count" do
    result = Outrank::ArticleImporter.new(article_data).call
    assert_equal :skipped, result[:status]
  end
end
```

**Acceptance**:
- [x] Test exists and initially fails
- [x] Uses fixture with existing outrank_id
- [x] Verifies no new record created
- [x] Returns skip status

---

### T3.2: Test - Response includes skip reason
**Priority**: P2
**Dependencies**: T3.1
**Files**: `test/services/outrank/webhook_processor_test.rb`

Write test that response includes skip details for duplicates.

**Acceptance**:
- [x] Test exists and initially fails
- [x] Response includes `status: "skipped"`
- [x] Response includes `reason: "duplicate"`

---

### T3.3: Implement duplicate detection
**Priority**: P2
**Dependencies**: T3.1, T3.2
**Files**: `app/services/outrank/article_importer.rb`

Add duplicate check to ArticleImporter before creating post.

**Acceptance**:
- [x] All T3.x tests pass
- [x] Logs duplicate detection
- [x] Returns structured result

---

## Phase 4: US4 - Content Storage (P2)

*Direct Markdown storage and sanitization.*

### T4.1: Test - Stores content_markdown directly
**Priority**: P2
**Dependencies**: T2.4
**Files**: `test/services/outrank/article_importer_test.rb`

Write test that `content_markdown` is stored as `body` without modification.

**Acceptance**:
- [x] Test exists and passes (likely already works from T2.4)
- [x] Confirms no HTML conversion attempted

---

### T4.2: Test - Sanitizes potentially dangerous content
**Priority**: P2
**Dependencies**: T2.4
**Files**: `test/services/outrank/article_importer_test.rb`

Write test that script tags and other dangerous content is sanitized.

**Test Scenario**:
```ruby
test "sanitizes dangerous content from markdown" do
  article_data = valid_article_data.merge(
    "content_markdown" => "<script>alert('xss')</script># Title"
  )

  Outrank::ArticleImporter.new(article_data).call
  post = BlogPost.last

  assert_not_includes post.body, "<script>"
end
```

**Acceptance**:
- [x] Test exists and initially fails
- [x] Script tags removed
- [x] Other dangerous elements handled

---

### T4.3: Implement content sanitization
**Priority**: P2
**Dependencies**: T4.2
**Files**: `app/services/outrank/article_importer.rb`

Add sanitization step before storing content.

**Acceptance**:
- [x] T4.2 test passes
- [x] Uses Rails sanitization helpers
- [x] Preserves safe Markdown formatting

---

## Phase 5: US5 - Cover Image Download (P3)

*Image download and Active Storage attachment.*

### T5.1: Test - Downloads and attaches cover image
**Priority**: P3
**Dependencies**: T2.4
**Files**: `test/services/outrank/image_downloader_test.rb`

Write test for ImageDownloader service with stubbed HTTP.

**Test Scenario**:
```ruby
test "downloads and attaches image" do
  post = blog_posts(:one)
  image_url = "https://example.com/image.jpg"

  stub_request(:get, image_url).to_return(
    body: file_fixture("test_image.jpg").read,
    headers: { "Content-Type" => "image/jpeg" }
  )

  Outrank::ImageDownloader.new(post, image_url).call

  assert post.cover_image.attached?
end
```

**Acceptance**:
- [x] Test exists and initially fails
- [x] Uses WebMock to stub HTTP request
- [x] Verifies Active Storage attachment

---

### T5.2: Test - Handles missing image gracefully
**Priority**: P3
**Dependencies**: T5.1
**Files**: `test/services/outrank/image_downloader_test.rb`

Write test that nil or blank image_url doesn't error.

**Acceptance**:
- [x] Test exists and initially fails
- [x] No exception raised
- [x] No attachment created

---

### T5.3: Test - Handles failed downloads gracefully
**Priority**: P3
**Dependencies**: T5.1
**Files**: `test/services/outrank/image_downloader_test.rb`

Write test that download errors are logged but don't block article creation.

**Test Scenario**:
```ruby
test "logs error and continues when download fails" do
  post = blog_posts(:one)
  image_url = "https://example.com/broken.jpg"

  stub_request(:get, image_url).to_return(status: 404)

  assert_nothing_raised do
    Outrank::ImageDownloader.new(post, image_url).call
  end

  assert_not post.cover_image.attached?
end
```

**Acceptance**:
- [x] Test exists and initially fails
- [x] No exception propagated
- [x] Error logged for debugging

---

### T5.4: Implement ImageDownloader service
**Priority**: P3
**Dependencies**: T5.1, T5.2, T5.3
**Files**: `app/services/outrank/image_downloader.rb`

Create service that downloads images and attaches via Active Storage.

**Acceptance**:
- [x] All T5.x tests pass
- [x] Uses `http` gem with timeout
- [x] Extracts filename from URL
- [x] Handles all error scenarios gracefully

---

### T5.5: Integrate ImageDownloader into ArticleImporter
**Priority**: P3
**Dependencies**: T5.4
**Files**: `app/services/outrank/article_importer.rb`

Call ImageDownloader after BlogPost creation.

**Acceptance**:
- [x] Image downloaded when `image_url` present
- [x] Article created even if image fails

---

## Phase 6: Controller Integration Tests

### T6.1: Integration test - Full success flow
**Priority**: P1
**Dependencies**: T2.7
**Files**: `test/controllers/api/webhooks/outrank_controller_test.rb`

End-to-end test of successful webhook processing.

**Acceptance**:
- [x] Posts created with correct data
- [x] Response matches API contract
- [x] Categories created as needed

---

### T6.2: Integration test - Malformed JSON
**Priority**: P2
**Dependencies**: T2.7
**Files**: `test/controllers/api/webhooks/outrank_controller_test.rb`

Test that malformed JSON returns 400.

**Acceptance**:
- [x] Returns 400 Bad Request
- [x] Error message in response

---

### T6.3: Integration test - Missing required fields
**Priority**: P2
**Dependencies**: T2.7
**Files**: `test/controllers/api/webhooks/outrank_controller_test.rb`

Test that missing `title` or `content_markdown` returns validation error.

**Acceptance**:
- [x] Returns 422 or error in results
- [x] Specific field mentioned

---

## Task Summary

| Phase | Focus | Tasks | Priority |
|-------|-------|-------|----------|
| 0 | Setup & Foundation | T0.1 - T0.5 | P0 |
| 1 | Authentication (US2) | T1.1 - T1.4 | P1 |
| 2 | Article Ingestion (US1) | T2.1 - T2.7 | P1 |
| 3 | Duplicate Handling (US3) | T3.1 - T3.3 | P2 |
| 4 | Content Storage (US4) | T4.1 - T4.3 | P2 |
| 5 | Image Download (US5) | T5.1 - T5.5 | P3 |
| 6 | Integration Tests | T6.1 - T6.3 | P1-P2 |

**Total Tasks**: 27
**Critical Path**: T0.1 → T0.3 → T1.4 → T2.4 → T2.6 → T2.7

---

## Implementation Order (Recommended)

1. **Phase 0**: All setup tasks (can be parallelized)
2. **Phase 1**: Authentication (T1.1-T1.4)
3. **Phase 2**: Core functionality (T2.1-T2.7)
4. **Phase 3**: Duplicate handling (T3.1-T3.3)
5. **Phase 4**: Content sanitization (T4.1-T4.3)
6. **Phase 5**: Image downloads (T5.1-T5.5)
7. **Phase 6**: Integration tests (T6.1-T6.3)

Each phase is independently deployable - the feature works at minimum viable after Phase 2 completes.
