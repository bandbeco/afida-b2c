# Data Model: Blog Foundation

**Feature**: 001-blog-foundation
**Date**: 2026-01-14

## Entity: BlogPost

Represents a single blog article with Markdown content.

### Attributes

| Attribute | Type | Constraints | Description |
|-----------|------|-------------|-------------|
| `id` | bigint | PK, auto | Primary key |
| `title` | string(255) | NOT NULL | Post headline |
| `slug` | string(255) | NOT NULL, UNIQUE, INDEX | URL identifier (auto-generated from title) |
| `body` | text | NOT NULL | Markdown content |
| `excerpt` | text | nullable | Optional summary for listings |
| `published` | boolean | NOT NULL, DEFAULT false | Public visibility flag |
| `published_at` | datetime | nullable, INDEX | Timestamp of first publication |
| `meta_title` | string(255) | nullable | Custom SEO title |
| `meta_description` | text | nullable | Custom SEO description |
| `created_at` | datetime | NOT NULL | Rails timestamp |
| `updated_at` | datetime | NOT NULL | Rails timestamp |

### Indexes

| Index | Columns | Type | Purpose |
|-------|---------|------|---------|
| `index_blog_posts_on_slug` | `slug` | UNIQUE | URL lookups, prevent duplicates |
| `index_blog_posts_on_published_at` | `published_at` | BTREE | Ordering published posts |
| `index_blog_posts_on_published` | `published` | BTREE | Filtering published/draft |

### Validations

| Field | Validation | Error Message |
|-------|------------|---------------|
| `title` | presence | "Title can't be blank" |
| `body` | presence | "Body can't be blank" |
| `slug` | presence | "Slug can't be blank" |
| `slug` | uniqueness | "Slug has already been taken" |
| `slug` | format (alphanumeric + hyphens) | "Slug contains invalid characters" |

### Callbacks

| Callback | Trigger | Behavior |
|----------|---------|----------|
| `before_validation` | Always | Generate slug from title if blank |
| `before_save` | `published` changed to true | Set `published_at` if nil |

### Scopes

| Scope | Query | Purpose |
|-------|-------|---------|
| `published` | `where(published: true)` | Filter to public posts |
| `drafts` | `where(published: false)` | Filter to draft posts |
| `recent` | `order(published_at: :desc)` | Order by publication date |

### Instance Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `excerpt_with_fallback` | String | Returns excerpt or first 160 chars of body (stripped of Markdown) |
| `meta_title_with_fallback` | String | Returns meta_title or title |
| `meta_description_with_fallback` | String | Returns meta_description or excerpt_with_fallback |
| `to_param` | String | Returns slug for URL generation |

## Relationships

```
BlogPost (standalone)
└── No associations in initial implementation
```

### Future Considerations (Not in Scope)

- `has_one_attached :featured_image` - Featured image for posts
- `belongs_to :author, class_name: "User"` - Multi-author support
- `has_and_belongs_to_many :tags` - Tagging system
- `belongs_to :category` - Category organization

## Migration

```ruby
class CreateBlogPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :blog_posts do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :body, null: false
      t.text :excerpt
      t.boolean :published, null: false, default: false
      t.datetime :published_at
      t.string :meta_title
      t.text :meta_description

      t.timestamps
    end

    add_index :blog_posts, :slug, unique: true
    add_index :blog_posts, :published_at
    add_index :blog_posts, :published
  end
end
```

## State Transitions

```
                    ┌─────────────┐
                    │   Draft     │
                    │ published:  │
                    │   false     │
                    └──────┬──────┘
                           │
                           │ publish (set published=true)
                           │ [sets published_at if nil]
                           ▼
                    ┌─────────────┐
                    │  Published  │
                    │ published:  │
                    │   true      │
                    └──────┬──────┘
                           │
                           │ unpublish (set published=false)
                           │ [published_at preserved]
                           ▼
                    ┌─────────────┐
                    │ Unpublished │
                    │ published:  │
                    │   false     │
                    │ (was pub'd) │
                    └─────────────┘
```

Note: `published_at` is only set on first publication and preserved thereafter.
