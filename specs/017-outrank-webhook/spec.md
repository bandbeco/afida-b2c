# Feature Specification: Outrank Webhook Integration

**Feature Branch**: `017-outrank-webhook`
**Created**: 2026-01-14
**Status**: Draft
**Input**: User description: "Integrate Outrank.so webhook to automatically receive and publish blog articles. The system receives article data from Outrank (title, content, images, SEO metadata), converts HTML to Markdown, downloads and attaches cover images, and creates BlogPost records. Includes webhook authentication, duplicate handling, and admin review workflow."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Automatic Article Ingestion (Priority: P1)

When Outrank.so generates a new blog article based on Afida's SEO keyword strategy, the article is automatically received and stored in the blog system as a draft, ready for admin review before publishing.

**Why this priority**: This is the core value proposition - eliminating manual copy-paste workflow and ensuring consistent article ingestion. Without this, the entire integration has no purpose.

**Independent Test**: Can be fully tested by sending a webhook payload to the endpoint and verifying a BlogPost record is created with correct field mappings.

**Acceptance Scenarios**:

1. **Given** Outrank sends a webhook with article data (title, content_markdown, meta_description, image_url, slug), **When** the webhook is received, **Then** a new BlogPost is created with the title, body (from content_markdown), meta_description, slug, and cover image attached.

2. **Given** Outrank sends an article with tags, **When** the webhook is processed, **Then** the first tag is used to find or create a matching BlogCategory for the post.

3. **Given** Outrank sends an article, **When** the webhook is processed successfully, **Then** the BlogPost is created with `published: false` so admins can review before publishing.

---

### User Story 2 - Secure Webhook Authentication (Priority: P1)

The webhook endpoint only accepts requests that are authenticated as coming from Outrank.so, preventing unauthorized parties from creating blog posts.

**Why this priority**: Security is critical - an unauthenticated endpoint would allow anyone to inject content into the blog. This is equally important as the core functionality.

**Independent Test**: Can be tested by sending requests with valid and invalid authentication credentials and verifying appropriate acceptance/rejection.

**Acceptance Scenarios**:

1. **Given** a webhook request with a valid Bearer token in the Authorization header, **When** the request is received, **Then** the system processes the article and returns a success response.

2. **Given** a webhook request without an Authorization header or with an invalid Bearer token, **When** the request is received, **Then** the system rejects the request with a 401 error and does not create any BlogPost.

3. **Given** the webhook secret is stored securely, **When** an admin needs to configure it, **Then** the secret is managed through secure application credentials (not in code or environment variables visible in logs).

---

### User Story 3 - Duplicate Article Handling (Priority: P2)

If Outrank sends the same article multiple times (e.g., due to retry logic or network issues), the system handles it gracefully without creating duplicate blog posts.

**Why this priority**: Webhook deliveries can be retried, so idempotency prevents data integrity issues. However, the core happy path works without this.

**Independent Test**: Can be tested by sending the same webhook payload twice and verifying only one BlogPost exists.

**Acceptance Scenarios**:

1. **Given** an article with a specific slug already exists in the system, **When** Outrank sends the same article again, **Then** the system either updates the existing article or ignores the duplicate (returning success to prevent retries).

2. **Given** an article is received that matches an existing article by slug, **When** the duplicate is detected, **Then** the system logs the duplicate attempt for debugging purposes.

---

### User Story 4 - Content Storage (Priority: P2)

Outrank provides article content in both Markdown and HTML formats. The system stores the Markdown content directly, matching the existing BlogPost storage format.

**Why this priority**: The BlogPost model stores content as Markdown. Outrank conveniently provides `content_markdown` directly, so no conversion is needed. This enables the P1 story to work correctly.

**Independent Test**: Can be tested by sending a webhook with `content_markdown` and verifying the stored body field contains the Markdown content.

**Acceptance Scenarios**:

1. **Given** Outrank sends article content with `content_markdown` field, **When** the webhook is processed, **Then** the body field contains the Markdown content directly.

2. **Given** Outrank sends Markdown content with images embedded as URLs, **When** the webhook is processed, **Then** image references are preserved in the Markdown.

3. **Given** Outrank sends content that could contain unsafe elements, **When** the webhook is processed, **Then** potentially dangerous content is sanitized before storage.

---

### User Story 5 - Cover Image Download (Priority: P3)

When an article includes a featured image URL, the system downloads the image and attaches it to the BlogPost via Active Storage, ensuring images are hosted on Afida's infrastructure.

**Why this priority**: Cover images enhance visual appeal but articles can function without them. This prevents external image dependency and ensures consistent image hosting.

**Independent Test**: Can be tested by sending a webhook with a featured_image_url and verifying the cover_image attachment exists on the created BlogPost.

**Acceptance Scenarios**:

1. **Given** Outrank sends an article with an `image_url`, **When** the webhook is processed, **Then** the image is downloaded and attached as the BlogPost's cover_image.

2. **Given** Outrank sends an article without a featured image, **When** the webhook is processed, **Then** the BlogPost is created successfully without a cover_image attachment.

3. **Given** the featured image URL is invalid or unreachable, **When** the webhook is processed, **Then** the BlogPost is still created successfully, the cover_image is left empty, and the failure is logged.

---

### Edge Cases

- What happens when Outrank sends malformed JSON? System returns an error response and logs the issue.
- What happens when the article title is missing? System rejects that article with a validation error but processes other articles in the batch.
- What happens when the image download times out? BlogPost is created without the image; failure is logged.
- What happens when a tag contains special characters? Category slug is generated safely using parameterize.
- What happens when the content_markdown is empty? BlogPost is rejected (body is required).
- What happens when the webhook endpoint is temporarily unavailable? Outrank's retry mechanism will resend; duplicates are handled via the Outrank `id` field.
- What happens when a batch contains multiple articles? All articles are processed, with individual success/failure tracking.
- What happens when the tags array is empty? BlogPost is created without a category association.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST accept incoming webhook POST requests at a dedicated endpoint
- **FR-002**: System MUST authenticate webhook requests using Bearer token in Authorization header before processing
- **FR-003**: System MUST reject unauthenticated requests with an appropriate error status
- **FR-004**: System MUST create a BlogPost record from valid webhook payloads
- **FR-005**: System MUST use Outrank's `content_markdown` field directly for storage (no conversion needed)
- **FR-006**: System MUST download and attach cover images from provided URLs
- **FR-007**: System MUST associate articles with BlogCategories using the first tag, creating categories if needed
- **FR-008**: System MUST handle duplicate articles using Outrank's unique `id` field without creating duplicate records
- **FR-009**: System MUST create articles with `published: false` by default for admin review
- **FR-010**: System MUST return appropriate success/error responses to Outrank
- **FR-011**: System MUST log webhook processing for debugging and monitoring
- **FR-012**: System MUST sanitize HTML content to prevent security vulnerabilities
- **FR-013**: System MUST extract or generate an excerpt if not provided by Outrank
- **FR-014**: System MUST map Outrank's SEO metadata to BlogPost's meta_title and meta_description fields
- **FR-015**: System MUST process multiple articles in a single webhook request (batch processing)
- **FR-016**: System MUST use Outrank's `id` field for idempotency checking (requires storing external ID)

### Key Entities

- **BlogPost**: Existing entity that stores blog articles. Receives data from webhook: title, slug, body (from content_markdown), excerpt (extracted from content), meta_title (from title), meta_description, cover_image (from image_url), blog_category_id (from first tag), published status.

- **BlogCategory**: Existing entity for organizing content. May be created automatically from Outrank's tags array.

- **Webhook Payload**: Incoming data structure from Outrank with structure:
  - `event_type`: Always "publish_articles"
  - `timestamp`: ISO 8601 timestamp
  - `data.articles[]`: Array of article objects containing:
    - `id`: Unique identifier (for idempotency)
    - `title`: Article title
    - `content_markdown`: Markdown content (use this)
    - `content_html`: HTML content (available but not needed)
    - `meta_description`: SEO description
    - `created_at`: ISO 8601 timestamp
    - `image_url`: Cover image URL
    - `slug`: URL-friendly slug
    - `tags`: Array of tag strings

- **Access Token**: Bearer token stored securely in application credentials, sent in Authorization header to verify requests originate from Outrank.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Articles sent from Outrank appear in the admin blog post list within 30 seconds of webhook delivery
- **SC-002**: 100% of authenticated webhook requests are processed successfully (no data loss)
- **SC-003**: 100% of unauthenticated requests are rejected (no unauthorized content creation)
- **SC-004**: Duplicate article submissions do not create duplicate BlogPost records
- **SC-005**: HTML to Markdown conversion preserves all headings, links, lists, and paragraph structure
- **SC-006**: Cover images from Outrank are successfully downloaded and attached for at least 95% of articles that include image URLs
- **SC-007**: Admins can review and publish Outrank-generated articles using the existing blog admin workflow
- **SC-008**: Failed webhook deliveries (validation errors, auth failures) return clear error messages to aid Outrank debugging

## Assumptions

- Outrank's webhook payload structure matches their documentation (confirmed: `event_type`, `timestamp`, `data.articles[]`)
- Authentication uses Bearer token in Authorization header (confirmed from documentation)
- Outrank provides `content_markdown` directly, eliminating need for HTML-to-Markdown conversion
- The existing BlogPost model and admin interface support all required fields without modification
- Active Storage is configured and working for image attachments in production
- Outrank provides a way to test webhooks by manually publishing an article from their dashboard
- Webhook payloads can contain multiple articles in a single request (batch processing required)

## Out of Scope

- Auto-publishing articles (all articles created as drafts for admin review)
- Editing articles back to Outrank (one-way sync only)
- Scheduling article publication dates from Outrank data
- Admin notifications when new articles arrive (can be added later)
- Bulk import of historical Outrank articles (only handles new webhook deliveries)
