# Research: Blog Foundation

**Feature**: 001-blog-foundation
**Date**: 2026-01-14

## Research Tasks

### 1. Markdown Rendering Library

**Decision**: Redcarpet gem

**Rationale**:
- Battle-tested Ruby gem with excellent performance
- Supports GitHub-flavored Markdown (fenced code blocks, tables, autolinks)
- Built-in HTML sanitization via `filter_html: true` renderer option
- Simple API: instantiate renderer + markdown processor, call `render()`
- Actively maintained, widely used in Rails ecosystem

**Alternatives Considered**:
| Library | Pros | Cons | Why Rejected |
|---------|------|------|--------------|
| Kramdown | Pure Ruby, extensible | Slower, more complex API | Performance concerns |
| CommonMarker | Fast (C binding) | Less flexible, fewer extensions | Redcarpet is sufficient |
| Action Text | Built-in, WYSIWYG | Overkill, adds Trix/JS complexity | Too heavy for simple blog |

**Implementation Notes**:
```ruby
# app/helpers/markdown_helper.rb
renderer = Redcarpet::Render::HTML.new(filter_html: true, hard_wrap: true)
markdown = Redcarpet::Markdown.new(renderer, autolink: true, fenced_code_blocks: true, tables: true)
markdown.render(text).html_safe
```

### 2. Slug Generation Pattern

**Decision**: Follow existing Product model pattern using `parameterize`

**Rationale**:
- Product model already uses slugs successfully for SEO-friendly URLs
- `String#parameterize` handles Unicode, special characters, whitespace
- Uniqueness enforced at database level with unique index
- Callback on `before_validation` to auto-generate from title

**Existing Pattern (from Product)**:
```ruby
# Product generates slug in generate_slug method
before_validation :generate_slug
def generate_slug
  self.slug = [size, colour, material, name].compact.join("-").parameterize if slug.blank?
end
```

**BlogPost Adaptation**:
```ruby
before_validation :generate_slug
def generate_slug
  self.slug = title.parameterize if slug.blank? && title.present?
end
```

### 3. Admin Controller Pattern

**Decision**: Inherit from `Admin::ApplicationController`

**Rationale**:
- Existing admin controllers (Products, Categories, Orders) use this pattern
- Provides authentication via `require_admin` before_action
- Uses `admin` layout automatically
- Consistent with codebase conventions

**Existing Pattern**:
```ruby
module Admin
  class ProductsController < Admin::ApplicationController
    before_action :set_product, only: %i[show edit update destroy]
    # CRUD actions...
  end
end
```

### 4. Public Controller Pattern

**Decision**: Follow `ProductsController` pattern with `allow_unauthenticated_access`

**Rationale**:
- ProductsController demonstrates correct pattern for public-facing content
- Uses `find_by!` with slug parameter for clean 404 handling
- Returns 404 for unpublished content (mimics inactive product behavior)

**Existing Pattern**:
```ruby
class ProductsController < ApplicationController
  allow_unauthenticated_access

  def show
    @product = Product.active.find_by!(slug: params[:slug])
  rescue ActiveRecord::RecordNotFound
    render file: Rails.root.join("public", "404.html"), status: :not_found, layout: false
  end
end
```

### 5. View Styling Pattern

**Decision**: Use existing TailwindCSS + DaisyUI patterns

**Rationale**:
- Admin forms use `fieldset`, `fieldset-legend`, `input`, `textarea`, `checkbox` DaisyUI classes
- Public pages use standard Tailwind utilities with consistent spacing
- Grid layouts with `grid-cols-*` for responsive design

**Key Classes to Use**:
- Forms: `fieldset`, `fieldset-legend`, `label`, `input`, `textarea`, `checkbox`
- Cards: `card`, `card-body`, `bg-base-100`, `shadow`
- Buttons: `btn`, `btn-primary`, `btn-sm`
- Status badges: `badge`, `badge-success`, `badge-warning`

### 6. SEO Implementation

**Decision**: Follow existing SEO helper patterns

**Rationale**:
- `SeoHelper` provides structured data methods (`product_structured_data`, etc.)
- Products/Categories use `meta_title` and `meta_description` fields with fallbacks
- Canonical URLs via `canonical_url` helper
- Sitemap inclusion via `SitemapGeneratorService`

**Required for BlogPost**:
- Add to `SitemapGeneratorService` for sitemap.xml inclusion
- Meta title/description fields with fallback to post title/excerpt
- Canonical URL on show page
- Consider Article structured data (future enhancement)

## Technology Decisions Summary

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Markdown rendering | Redcarpet gem | Fast, secure, feature-rich |
| Slug generation | `String#parameterize` | Existing pattern, Unicode-safe |
| Admin authentication | `Admin::ApplicationController` | Consistent with existing admin |
| Public routes | `allow_unauthenticated_access` | Consistent with Products |
| Styling | TailwindCSS + DaisyUI | Existing stack |
| SEO | Existing helpers + sitemap | Constitution compliance |

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Markdown XSS vulnerability | Low | High | Use `filter_html: true` in renderer |
| Duplicate slugs | Low | Medium | Database unique constraint + validation |
| Performance with long posts | Low | Low | Markdown renders quickly; cache if needed |

## Open Questions

None - all technical decisions resolved based on existing codebase patterns.
