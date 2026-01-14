# Routes Contract: Blog Foundation

**Feature**: 001-blog-foundation
**Date**: 2026-01-14

## Public Routes

| Method | Path | Controller#Action | Purpose |
|--------|------|-------------------|---------|
| GET | `/blog` | `blog_posts#index` | List published posts |
| GET | `/blog/:slug` | `blog_posts#show` | View single post |

### Route Definition

```ruby
resources :blog_posts, only: [:index, :show], path: "blog", param: :slug
```

### URL Helpers

| Helper | Example Output |
|--------|----------------|
| `blog_posts_path` | `/blog` |
| `blog_post_path(post)` | `/blog/eco-friendly-packaging-guide` |

## Admin Routes

| Method | Path | Controller#Action | Purpose |
|--------|------|-------------------|---------|
| GET | `/admin/blog_posts` | `admin/blog_posts#index` | List all posts |
| GET | `/admin/blog_posts/new` | `admin/blog_posts#new` | New post form |
| POST | `/admin/blog_posts` | `admin/blog_posts#create` | Create post |
| GET | `/admin/blog_posts/:id/edit` | `admin/blog_posts#edit` | Edit post form |
| PATCH | `/admin/blog_posts/:id` | `admin/blog_posts#update` | Update post |
| DELETE | `/admin/blog_posts/:id` | `admin/blog_posts#destroy` | Delete post |

### Route Definition

```ruby
namespace :admin do
  resources :blog_posts
end
```

### URL Helpers

| Helper | Example Output |
|--------|----------------|
| `admin_blog_posts_path` | `/admin/blog_posts` |
| `new_admin_blog_post_path` | `/admin/blog_posts/new` |
| `edit_admin_blog_post_path(post)` | `/admin/blog_posts/1/edit` |
| `admin_blog_post_path(post)` | `/admin/blog_posts/1` |

## Response Codes

### Public Controller

| Scenario | Status | Response |
|----------|--------|----------|
| Index with posts | 200 | HTML listing |
| Index empty | 200 | HTML with empty state |
| Show published | 200 | HTML post |
| Show unpublished | 404 | 404 page |
| Show non-existent | 404 | 404 page |

### Admin Controller

| Scenario | Status | Response |
|----------|--------|----------|
| Index (authenticated) | 200 | HTML listing |
| Index (unauthenticated) | 302 | Redirect to root |
| Create success | 302 | Redirect to index |
| Create failure | 422 | Re-render form |
| Update success | 303 | Redirect to index |
| Update failure | 422 | Re-render form |
| Destroy success | 303 | Redirect to index |

## Complete Routes.rb Addition

```ruby
# In config/routes.rb

# Public blog routes
resources :blog_posts, only: [:index, :show], path: "blog", param: :slug

# Admin blog routes (inside existing namespace :admin block)
namespace :admin do
  # ... existing routes ...
  resources :blog_posts
end
```
