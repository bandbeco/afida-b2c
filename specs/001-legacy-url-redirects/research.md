# Research: Legacy URL Smart Redirects

**Feature**: 001-legacy-url-redirects
**Date**: 2025-11-13
**Status**: Complete

## Purpose

Research technical decisions for implementing a database-driven redirect system using Rack middleware, PostgreSQL, and Rails 8. This document resolves all unknowns from the technical context and establishes best practices for implementation.

## Research Topics

### 1. Rack Middleware for URL Interception

**Decision**: Implement custom Rack middleware inserted early in the middleware stack

**Rationale**:
- Rack middleware executes before Rails routing, minimizing overhead
- Direct access to HTTP request/response objects for efficient 301 redirects
- Can short-circuit request processing (return redirect without reaching Rails router)
- Standard Rails pattern for request-level concerns (see Rack::Deflater, Rack::Auth, etc.)

**Implementation Approach**:
```ruby
class LegacyRedirectMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    if request.path.start_with?('/product/')
      # Lookup redirect, return [301, headers, body] or fall through
    end

    @app.call(env)  # Fall through to next middleware/Rails
  end
end
```

**Alternatives Considered**:
- **Rails controller concern**: Rejected - would require routing all `/product/*` to a controller, adding overhead
- **Nginx/Apache rewrite rules**: Rejected - would require deployment-time updates, no analytics, no admin UI
- **Rails routing constraint**: Rejected - still requires routing overhead, less flexible than middleware

**Best Practices**:
- Register middleware in `config/application.rb` using `config.middleware.use`
- Position after `ActionDispatch::Session::CookieStore` if session access needed
- Use database connection pooling (Rails handles automatically)
- Cache database lookups in production (optional future optimization)

### 2. Case-Insensitive Database Queries in PostgreSQL

**Decision**: Use PostgreSQL `LOWER()` function with functional index for case-insensitive lookups

**Rationale**:
- PostgreSQL is case-sensitive by default for text comparison
- `LOWER()` function converts to lowercase for comparison
- Functional index `CREATE INDEX ... ON LOWER(legacy_path)` ensures O(1) lookups
- More portable than `CITEXT` extension (no additional setup required)

**Implementation Approach**:
```ruby
# Migration
add_index :legacy_redirects, 'LOWER(legacy_path)', unique: true

# Model query
LegacyRedirect.where('LOWER(legacy_path) = ?', path.downcase).first
```

**Alternatives Considered**:
- **CITEXT column type**: Requires PostgreSQL extension, overkill for single-column case-insensitivity
- **ILIKE operator**: Slower than indexed `LOWER()`, designed for pattern matching not exact matches
- **Application-level normalization only**: Doesn't handle URLs typed with different cases

**Best Practices**:
- Store legacy_path in original case (for display in admin)
- Always query using `LOWER(legacy_path)` with functional index
- Add unique constraint on lowercase to prevent duplicates
- Document in model comments that lookups are case-insensitive

### 3. URL Parameter Extraction and Normalization

**Decision**: Use regex pattern matching with named captures, store in JSONB, normalize against product variants

**Rationale**:
- Legacy URLs contain size/colour in text (e.g., `/product/12-310-x-310mm-pizza-box-kraft`)
- JSONB column allows flexible storage of extracted parameters
- Normalization required to match current product variant options
- Pattern matching enables handling variations (e.g., "12oz", "340ml", "Kraft", "kraft")

**Implementation Approach**:
```ruby
# Extract parameters from legacy URL
legacy_path = "/product/12-310-x-310mm-pizza-box-kraft"

# Pattern: /product/{size}-{dimensions}-{name}-{colour}
if legacy_path =~ %r{/product/(\d+)-.+-(.+)$}
  size = $1  # "12"
  colour = $2  # "kraft"

  # Normalize against product variants
  variant_params = {
    size: normalize_size(size, product),
    colour: normalize_colour(colour, product)
  }
end

# Store in JSONB column
redirect.variant_params = variant_params  # {"size": "12\"", "colour": "Kraft"}
```

**Normalization Logic**:
- **Size**: Match numeric portion (e.g., "12" → "12\"" or "12oz")
- **Colour**: Capitalize first letter (e.g., "kraft" → "Kraft", "white" → "White")
- **Fallback**: If no match found, store nil (redirect to product without pre-selection)

**Alternatives Considered**:
- **Separate columns for each parameter**: Rejected - not flexible for future parameters
- **String column with delimiter**: Rejected - JSONB provides structure and queryability
- **No normalization**: Rejected - variant parameters won't match current product options

**Best Practices**:
- Validate extracted parameters against actual product variants
- Log warnings when parameters don't match (helps identify data quality issues)
- Store both extracted and normalized values for debugging (optional)
- Handle missing parameters gracefully (redirect without query params)

### 4. 301 Redirect Best Practices for SEO

**Decision**: Use HTTP 301 (Permanent Redirect) with proper headers and no redirect chains

**Rationale**:
- 301 signals to search engines that the move is permanent
- Search engines transfer ~90-99% of link equity to new URL
- Proper headers prevent caching issues and preserve query parameters
- Single redirect hop maintains performance and SEO value

**Implementation Approach**:
```ruby
# Return 301 with Location header
[301, {
  'Location' => new_url,
  'Content-Type' => 'text/html',
  'Cache-Control' => 'public, max-age=86400'  # Cache redirects for 24h
}, ['Redirecting...']]
```

**SEO Considerations**:
- **Always 301**: Never 302 (temporary) for permanent URL changes
- **Single hop**: Legacy URL → New URL (no intermediary redirects)
- **Preserve query parameters**: UTM tracking, referral codes, etc.
- **Update sitemap**: Include new URLs, remove old URLs after deployment
- **Submit to Google Search Console**: Notify search engines of URL changes

**Alternatives Considered**:
- **302 redirect**: Rejected - temporary redirect, search engines won't transfer authority
- **Meta refresh**: Rejected - not recognized by search engines as redirect
- **JavaScript redirect**: Rejected - search engines may not execute JavaScript

**Best Practices**:
- Monitor redirect usage (hit_count) to identify high-value URLs
- Set reasonable cache TTL (24h) to allow updates without immediate propagation
- Log unmapped URLs to identify additional redirects needed
- Include redirect mapping in sitemap or submit changed URLs to GSC
- Keep redirects active for at least 1 year (industry standard)

## Summary of Technical Decisions

| Decision Point | Choice | Key Rationale |
|---|---|---|
| **Interception Mechanism** | Rack middleware | Executes before routing, minimal overhead |
| **Case-Insensitive Lookup** | `LOWER()` with functional index | O(1) performance, no extensions required |
| **Parameter Storage** | JSONB column | Flexible, structured, queryable |
| **Parameter Extraction** | Regex with normalization | Handles variations, matches current variants |
| **Redirect Type** | HTTP 301 | Permanent redirect, preserves SEO authority |
| **Cache Strategy** | 24h CDN cache | Balances performance with update flexibility |

## Open Questions & Assumptions

**Assumptions**:
- All 63 legacy URLs follow consistent pattern (verified by reviewing results.json)
- Current product database is accessible during parameter normalization
- Admin authentication already exists (reuse existing `/admin` authentication)
- Results.json file location is known or will be provided

**Resolved**:
- ✅ Middleware positioning determined (early in stack, after session)
- ✅ Database indexing strategy defined (functional index on LOWER)
- ✅ Parameter normalization approach established (regex + match against variants)
- ✅ SEO best practices confirmed (301, single hop, preserve params)

**No further clarifications needed** - Ready for Phase 1 (Design & Contracts)
