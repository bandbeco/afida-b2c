# Feature Specification: Blog Foundation

**Feature Branch**: `001-blog-foundation`
**Created**: 2026-01-14
**Status**: Draft
**Input**: User description: "Add blog foundation with routes, model, controller, and views for a simple Markdown-based blog"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Blog Posts (Priority: P1)

As a site visitor, I want to browse and read blog posts so I can learn about eco-friendly catering practices, company news, and product guides.

**Why this priority**: The primary purpose of a blog is content consumption. Without the ability to view posts, the blog has no value to visitors. This is the core read experience.

**Independent Test**: Can be fully tested by creating a blog post in the database and navigating to `/blog` to see the listing, then clicking through to read the full post.

**Acceptance Scenarios**:

1. **Given** there are published blog posts, **When** I visit `/blog`, **Then** I see a list of posts showing title, excerpt, and publication date ordered by most recent first
2. **Given** I am viewing the blog listing, **When** I click on a post title, **Then** I am taken to the full post at `/blog/[slug]`
3. **Given** a post exists with Markdown content, **When** I view the post, **Then** the Markdown is rendered as formatted HTML
4. **Given** there are no published posts, **When** I visit `/blog`, **Then** I see a friendly message indicating no posts are available yet

---

### User Story 2 - Create Blog Posts (Priority: P1)

As a site administrator, I want to create new blog posts so I can publish content for visitors to read.

**Why this priority**: Without the ability to create posts, there is no content to display. This is essential for the blog to function.

**Independent Test**: Can be fully tested by logging into admin, navigating to `/admin/blog_posts/new`, filling out the form, and verifying the post appears in the listing.

**Acceptance Scenarios**:

1. **Given** I am in the admin area, **When** I navigate to blog posts and click "New Post", **Then** I see a form with fields for title, body (Markdown), excerpt, and published status
2. **Given** I have filled out the new post form, **When** I submit the form, **Then** the post is saved and I see a success confirmation
3. **Given** I create a post without checking "Published", **When** a visitor tries to access the post, **Then** they receive a 404 not found response

---

### User Story 3 - Edit Blog Posts (Priority: P2)

As a site administrator, I want to edit existing blog posts so I can fix errors, update content, or change publication status.

**Why this priority**: Content often needs updates after initial publication. This enables the content lifecycle but is secondary to create/view.

**Independent Test**: Can be fully tested by creating a post, then editing it via `/admin/blog_posts/[id]/edit` and verifying changes persist.

**Acceptance Scenarios**:

1. **Given** a blog post exists, **When** I navigate to edit it in admin, **Then** the form is pre-filled with existing content
2. **Given** I am editing a post, **When** I change the title and save, **Then** the updated title appears on the public blog
3. **Given** a draft post exists, **When** I check "Published" and save, **Then** the post becomes visible on the public blog and the publication date is recorded

---

### User Story 4 - Delete Blog Posts (Priority: P3)

As a site administrator, I want to delete blog posts that are no longer relevant.

**Why this priority**: Deleting content is a lower-frequency operation and can be worked around by unpublishing posts.

**Independent Test**: Can be fully tested by creating a post, deleting it via admin, and verifying it no longer appears in listings or is accessible by URL.

**Acceptance Scenarios**:

1. **Given** a blog post exists, **When** I click delete in the admin listing, **Then** the post is permanently removed
2. **Given** I have deleted a post, **When** a visitor tries to access its former URL, **Then** they receive a 404 response

---

### Edge Cases

- What happens when a visitor accesses a valid slug for an unpublished post? They should receive a 404 response.
- What happens when an admin creates a post with a title that generates a duplicate slug? The system should generate a unique slug (e.g., append a number).
- What happens when a post has no excerpt defined? The system should display a truncated version of the body content.
- How does the system handle empty blog listings? Display a user-friendly empty state message.
- What happens when Markdown contains potentially unsafe HTML? The system should sanitize output to prevent XSS attacks.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST store blog posts with title, body (Markdown), excerpt, publication status, and SEO fields
- **FR-002**: System MUST generate URL-friendly slugs from post titles
- **FR-003**: System MUST ensure slugs are unique across all posts
- **FR-004**: System MUST render Markdown content as formatted HTML on public pages
- **FR-005**: System MUST sanitize rendered HTML to prevent cross-site scripting attacks
- **FR-006**: System MUST only display published posts to public visitors
- **FR-007**: System MUST record the publication date when a post is first published
- **FR-008**: System MUST order public blog listings by publication date (newest first)
- **FR-009**: System MUST provide fallback excerpt from body content when no excerpt is specified
- **FR-010**: System MUST provide admin interface for creating, editing, and deleting posts
- **FR-011**: System MUST show all posts (published and unpublished) in admin listing with status indicators
- **FR-012**: System MUST support optional SEO meta title and description fields per post

### Key Entities

- **BlogPost**: Represents a single blog article with:
  - Title (required): The headline displayed to readers
  - Slug (required, unique): URL-friendly identifier derived from title
  - Body (required): Main content written in Markdown format
  - Excerpt (optional): Short summary for listings; falls back to truncated body
  - Published (boolean): Controls public visibility
  - Published At (timestamp): When the post first became public
  - Meta Title (optional): Custom title for search engines
  - Meta Description (optional): Custom description for search engines

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Administrators can create and publish a new blog post in under 3 minutes
- **SC-002**: Blog posts load for visitors in under 2 seconds
- **SC-003**: 100% of published posts are accessible via their slug URL
- **SC-004**: 100% of unpublished posts return 404 to public visitors
- **SC-005**: Markdown content renders correctly with headings, links, lists, and code blocks
- **SC-006**: Blog listing page displays at least 10 posts with pagination for larger collections

## Assumptions

- Single author model: No need for author attribution or multi-author support
- Flat organization: No categories or tags in initial implementation
- Simple publishing: Boolean published flag without scheduling or workflow
- Existing admin authentication: Uses current admin area access patterns
- Standard pagination: 10 posts per page is appropriate default
