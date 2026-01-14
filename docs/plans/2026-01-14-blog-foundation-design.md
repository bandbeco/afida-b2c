# Blog Foundation Design

## Overview

Add a simple blog to the Afida e-commerce site for mixed-purpose content: SEO/content marketing, company news, and educational resources.

## Design Decisions

- **Single author** - No author profiles or bylines needed
- **Flat organization** - No categories or tags initially (can add later)
- **Simple publishing** - Boolean published flag, no draft workflow
- **Markdown content** - Lightweight, no Action Text complexity
- **URL structure** - `/blog` and `/blog/:slug`

## Data Model

### `blog_posts` table

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| `id` | bigint | PK | Primary key |
| `title` | string | NOT NULL | Post title |
| `slug` | string | NOT NULL, UNIQUE, INDEX | URL identifier |
| `body` | text | NOT NULL | Markdown content |
| `excerpt` | text | nullable | Optional summary (falls back to truncated body) |
| `published` | boolean | NOT NULL, DEFAULT false | Visibility flag |
| `published_at` | datetime | nullable, INDEX | When first published |
| `meta_title` | string | nullable | SEO title override |
| `meta_description` | text | nullable | SEO description override |
| `created_at` | datetime | NOT NULL | Rails timestamp |
| `updated_at` | datetime | NOT NULL | Rails timestamp |

### Model Behaviors

- Slug auto-generates from title using `parameterize`
- `published_at` set to current time when `published` changes false → true
- Default scope: `published.order(published_at: :desc)` for public queries
- `excerpt_with_fallback` method returns excerpt or truncated body (160 chars)

## Routes

### Public

```ruby
resources :blog_posts, only: [:index, :show], path: "blog", param: :slug
```

| URL | Controller#Action |
|-----|-------------------|
| `GET /blog` | `blog_posts#index` |
| `GET /blog/:slug` | `blog_posts#show` |

### Admin

```ruby
namespace :admin do
  resources :blog_posts
end
```

| URL | Controller#Action |
|-----|-------------------|
| `GET /admin/blog_posts` | `admin/blog_posts#index` |
| `GET /admin/blog_posts/new` | `admin/blog_posts#new` |
| `POST /admin/blog_posts` | `admin/blog_posts#create` |
| `GET /admin/blog_posts/:id/edit` | `admin/blog_posts#edit` |
| `PATCH /admin/blog_posts/:id` | `admin/blog_posts#update` |
| `DELETE /admin/blog_posts/:id` | `admin/blog_posts#destroy` |

## Controllers

### `BlogPostsController` (public)

- `allow_unauthenticated_access`
- `index`: Fetch published posts, paginated
- `show`: Find by slug, 404 if not published

### `Admin::BlogPostsController`

- Standard CRUD
- Shows all posts (draft and published)
- No authentication check initially (matches existing admin pattern)

## Views

### Public

- `blog_posts/index.html.erb` - Card grid of posts with title, excerpt, date
- `blog_posts/show.html.erb` - Full post with rendered markdown

### Admin

- `admin/blog_posts/index.html.erb` - Table with title, status badge, dates, actions
- `admin/blog_posts/new.html.erb` - New post page
- `admin/blog_posts/edit.html.erb` - Edit post page
- `admin/blog_posts/_form.html.erb` - Shared form partial

## Markdown Implementation

### Gem

Add `redcarpet` to Gemfile for Markdown rendering.

### Helper

`app/helpers/markdown_helper.rb`:

```ruby
module MarkdownHelper
  def render_markdown(text)
    return "" if text.blank?

    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,
      hard_wrap: true,
      link_attributes: { rel: "noopener noreferrer" }
    )

    markdown = Redcarpet::Markdown.new(renderer,
      autolink: true,
      fenced_code_blocks: true,
      tables: true,
      strikethrough: true,
      no_intra_emphasis: true
    )

    markdown.render(text).html_safe
  end
end
```

## Files to Create

1. `db/migrate/TIMESTAMP_create_blog_posts.rb`
2. `app/models/blog_post.rb`
3. `app/controllers/blog_posts_controller.rb`
4. `app/controllers/admin/blog_posts_controller.rb`
5. `app/views/blog_posts/index.html.erb`
6. `app/views/blog_posts/show.html.erb`
7. `app/views/admin/blog_posts/index.html.erb`
8. `app/views/admin/blog_posts/new.html.erb`
9. `app/views/admin/blog_posts/edit.html.erb`
10. `app/views/admin/blog_posts/_form.html.erb`
11. `app/helpers/markdown_helper.rb`
12. `test/fixtures/blog_posts.yml`
13. `test/models/blog_post_test.rb`
14. `test/controllers/blog_posts_controller_test.rb`

## Future Enhancements (Not in Scope)

- Categories/tags for organization
- Featured image via Active Storage
- RSS feed
- Related posts
- Social sharing
