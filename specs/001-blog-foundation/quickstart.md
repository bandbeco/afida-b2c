# Quickstart: Blog Foundation

**Feature**: 001-blog-foundation
**Date**: 2026-01-14

## Prerequisites

- Ruby 3.4.7
- Rails 8.1.1
- PostgreSQL running
- Project dependencies installed (`bin/setup`)

## Implementation Order

Follow this sequence for TDD-compliant development:

### 1. Add Redcarpet Gem

```bash
bundle add redcarpet
```

### 2. Generate Migration

```bash
rails generate migration CreateBlogPosts
```

Edit migration per `data-model.md`, then:

```bash
rails db:migrate
```

### 3. Create Fixtures First

```yaml
# test/fixtures/blog_posts.yml
published_post:
  title: "Eco-Friendly Packaging Guide"
  slug: "eco-friendly-packaging-guide"
  body: "# Introduction\n\nThis guide covers..."
  excerpt: "A comprehensive guide to eco-friendly packaging."
  published: true
  published_at: <%= 1.day.ago %>

draft_post:
  title: "Upcoming Features"
  slug: "upcoming-features"
  body: "We're working on exciting new products..."
  published: false
  published_at: null
```

### 4. Write Model Tests (RED)

```bash
rails test test/models/blog_post_test.rb
```

Tests should fail initially.

### 5. Implement Model (GREEN)

Create `app/models/blog_post.rb` with validations, callbacks, scopes.

```bash
rails test test/models/blog_post_test.rb
# Should pass
```

### 6. Write Controller Tests (RED)

```bash
rails test test/controllers/blog_posts_controller_test.rb
rails test test/controllers/admin/blog_posts_controller_test.rb
```

### 7. Implement Controllers & Views (GREEN)

Create controllers and views per the plan.

### 8. Add Routes

Update `config/routes.rb` per `contracts/routes.md`.

### 9. Final Verification

```bash
# Run all tests
rails test

# Run linter
rubocop

# Run security check
brakeman

# Manual verification
bin/dev
# Visit http://localhost:3000/blog
# Visit http://localhost:3000/admin/blog_posts
```

## Key Files to Create

| File | Purpose |
|------|---------|
| `app/models/blog_post.rb` | Model with validations, callbacks |
| `app/controllers/blog_posts_controller.rb` | Public index/show |
| `app/controllers/admin/blog_posts_controller.rb` | Admin CRUD |
| `app/views/blog_posts/index.html.erb` | Public listing |
| `app/views/blog_posts/show.html.erb` | Single post view |
| `app/views/admin/blog_posts/index.html.erb` | Admin listing |
| `app/views/admin/blog_posts/new.html.erb` | New form wrapper |
| `app/views/admin/blog_posts/edit.html.erb` | Edit form wrapper |
| `app/views/admin/blog_posts/_form.html.erb` | Shared form |
| `app/helpers/markdown_helper.rb` | `render_markdown` method |
| `test/fixtures/blog_posts.yml` | Test data |
| `test/models/blog_post_test.rb` | Model tests |
| `test/controllers/blog_posts_controller_test.rb` | Controller tests |

## Verification Checklist

- [ ] `rails test` passes
- [ ] `rubocop` passes
- [ ] `brakeman` shows no new warnings
- [ ] `/blog` shows published posts only
- [ ] `/blog/:slug` renders Markdown correctly
- [ ] `/admin/blog_posts` requires authentication
- [ ] Admin CRUD operations work
- [ ] Unpublished posts return 404 to public
- [ ] Slugs auto-generate from titles

## Common Issues

### Slug uniqueness violation

If you see "Slug has already been taken", the model should append a suffix:

```ruby
def generate_unique_slug
  base_slug = title.parameterize
  self.slug = base_slug
  counter = 1
  while BlogPost.exists?(slug: slug)
    self.slug = "#{base_slug}-#{counter}"
    counter += 1
  end
end
```

### Markdown not rendering

Ensure `render_markdown` output is marked `html_safe`:

```ruby
markdown.render(text).html_safe
```

### Admin redirect loop

Ensure user has `admin: true` in database. Check `Current.user&.admin?` returns true.
