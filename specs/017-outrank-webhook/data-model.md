# Data Model: Outrank Webhook Integration

**Feature**: 017-outrank-webhook
**Date**: 2026-01-14

## Entity Overview

This feature extends the existing `BlogPost` model and uses the existing `BlogCategory` model. No new tables are created.

```
┌─────────────────────┐         ┌─────────────────────┐
│     BlogPost        │────────▶│   BlogCategory      │
│  (existing + new)   │  belongs│     (existing)      │
│                     │    to   │                     │
└─────────────────────┘         └─────────────────────┘
         │
         │ has_one_attached
         ▼
┌─────────────────────┐
│   cover_image       │
│  (Active Storage)   │
└─────────────────────┘
```

---

## BlogPost (Modified)

**Table**: `blog_posts`

### Existing Fields (No Changes)

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | bigint | PK, auto | Primary key |
| `title` | string | NOT NULL | Article title |
| `slug` | string | NOT NULL, UNIQUE | URL-friendly identifier |
| `body` | text | NOT NULL | Markdown content |
| `excerpt` | text | nullable | Short description |
| `published` | boolean | NOT NULL, default: false | Publication status |
| `published_at` | datetime | nullable | When first published |
| `meta_title` | string | nullable | SEO title override |
| `meta_description` | text | nullable | SEO description |
| `blog_category_id` | bigint | FK, nullable | Category association |
| `created_at` | datetime | NOT NULL | Record creation |
| `updated_at` | datetime | NOT NULL | Last update |

### New Field

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `outrank_id` | string | UNIQUE, nullable | Outrank's unique article identifier for idempotency |

### Indexes

| Index | Columns | Type | Purpose |
|-------|---------|------|---------|
| `index_blog_posts_on_outrank_id` | `outrank_id` | UNIQUE | Fast duplicate detection |

### Migration

```ruby
class AddOutrankIdToBlogPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :blog_posts, :outrank_id, :string
    add_index :blog_posts, :outrank_id, unique: true
  end
end
```

---

## BlogCategory (Unchanged)

**Table**: `blog_categories`

Used to categorize articles. Outrank's first tag maps to this entity.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | bigint | PK, auto | Primary key |
| `name` | string | NOT NULL | Category display name |
| `slug` | string | NOT NULL, UNIQUE | URL-friendly identifier |
| `created_at` | datetime | NOT NULL | Record creation |
| `updated_at` | datetime | NOT NULL | Last update |

### Behavior for Webhook

- When processing an article with tags, find category by `name` (case-sensitive)
- If not found, create new category with `slug` generated via `parameterize`
- Articles without tags are created with `blog_category_id: nil`

---

## Webhook Payload Mapping

### Outrank → BlogPost Field Mapping

| Outrank Field | BlogPost Field | Transformation |
|---------------|----------------|----------------|
| `id` | `outrank_id` | Direct |
| `title` | `title` | Direct |
| `slug` | `slug` | Direct |
| `content_markdown` | `body` | Direct |
| `meta_description` | `meta_description` | Direct |
| `title` | `meta_title` | Copy (fallback) |
| `image_url` | `cover_image` | Download & attach |
| `tags[0]` | `blog_category_id` | Find/create category |
| - | `excerpt` | Extract from body |
| - | `published` | Always `false` |
| - | `published_at` | `nil` |

### Sample Transformation

**Input (Outrank webhook)**:
```json
{
  "id": "123456",
  "title": "Eco-Friendly Packaging Guide",
  "slug": "eco-friendly-packaging-guide",
  "content_markdown": "# Introduction\n\nSustainable packaging...",
  "meta_description": "Learn about eco-friendly packaging options",
  "image_url": "https://outrank.so/images/packaging.jpg",
  "tags": ["sustainability", "packaging", "guides"]
}
```

**Output (BlogPost record)**:
```ruby
BlogPost.new(
  outrank_id: "123456",
  title: "Eco-Friendly Packaging Guide",
  slug: "eco-friendly-packaging-guide",
  body: "# Introduction\n\nSustainable packaging...",
  excerpt: "Sustainable packaging...",  # extracted
  meta_title: "Eco-Friendly Packaging Guide",
  meta_description: "Learn about eco-friendly packaging options",
  blog_category: BlogCategory.find_or_create_by!(name: "sustainability"),
  published: false,
  published_at: nil
  # cover_image attached separately via Active Storage
)
```

---

## Validation Rules

### BlogPost Validations (Existing)

```ruby
validates :title, presence: true
validates :body, presence: true
validates :slug, presence: true, uniqueness: true,
                 format: { with: /\A[a-z0-9-]+\z/ }
```

### Webhook-Specific Validation

The webhook processor validates incoming data before creating records:

1. **Required fields**: `id`, `title`, `content_markdown`, `slug`
2. **Slug format**: Must match existing BlogPost slug format
3. **Duplicate check**: Skip if `outrank_id` already exists

---

## State Transitions

```
┌─────────────────┐
│   Webhook       │
│   Received      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     exists     ┌─────────────────┐
│   Check         │───────────────▶│   Skip/Update   │
│   outrank_id    │                │   (log only)    │
└────────┬────────┘                └─────────────────┘
         │ new
         ▼
┌─────────────────┐
│   Create        │
│   BlogPost      │
│   (draft)       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Download      │──── failure ──▶ Continue without image
│   Cover Image   │
└────────┬────────┘
         │ success
         ▼
┌─────────────────┐
│   Attach Image  │
│   via Active    │
│   Storage       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Return        │
│   Success       │
└─────────────────┘
```

---

## Fixtures Update

Add to `test/fixtures/blog_posts.yml`:

```yaml
outrank_imported:
  title: "Imported from Outrank"
  slug: "imported-from-outrank"
  body: "Content from Outrank webhook"
  excerpt: "Content from Outrank..."
  published: false
  outrank_id: "outrank-test-123"
  blog_category: guides

duplicate_outrank:
  title: "Duplicate Test Article"
  slug: "duplicate-test-article"
  body: "This tests duplicate handling"
  published: false
  outrank_id: "outrank-duplicate-456"
```
