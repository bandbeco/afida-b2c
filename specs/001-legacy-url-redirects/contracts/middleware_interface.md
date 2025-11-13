# Middleware Interface Contract: Legacy Redirect Middleware

**Feature**: 001-legacy-url-redirects
**Date**: 2025-11-13
**Type**: Rack Middleware

## Purpose

Defines the behavior of Rack middleware that intercepts HTTP requests to legacy product URLs and redirects them to the new product structure with extracted variant parameters.

## Middleware: LegacyRedirectMiddleware

**File**: `app/middleware/legacy_redirect_middleware.rb`
**Position**: Early in Rack middleware stack (after session, before routing)
**Scope**: All HTTP requests to the application

## Initialization

**Registration** (in `config/application.rb`):
```ruby
config.middleware.use LegacyRedirectMiddleware
```

**Constructor**:
```ruby
def initialize(app)
  @app = app  # Next middleware in chain
end
```

**No configuration required** - Middleware is self-contained

## Request Interception Logic

### Entry Point

**Method**: `call(env)`
**Parameters**:
- `env` (Hash): Rack environment hash containing request details

**Return Value**:
- Tuple: `[status, headers, body]` if redirect found
- Pass-through: `@app.call(env)` if no redirect match

### Decision Flow

```
1. Extract request path from env
2. Check if path starts with "/product/"
   ├─ NO → Pass request to next middleware (@app.call(env))
   └─ YES → Continue to step 3
3. Normalize path (downcase, strip trailing slash)
4. Query database for matching redirect
   ├─ NOT FOUND → Pass request to next middleware (@app.call(env))
   ├─ FOUND + INACTIVE → Pass request to next middleware (@app.call(env))
   └─ FOUND + ACTIVE → Continue to step 5
5. Increment hit counter (async, non-blocking)
6. Build target URL with variant parameters
7. Preserve existing query parameters
8. Return 301 redirect response
```

## Interface Contract

### Input (Rack Environment)

**Required Keys**:
| Key | Type | Description |
|---|---|---|
| `REQUEST_METHOD` | String | HTTP method (GET, POST, etc.) |
| `PATH_INFO` | String | Request path (e.g., `/product/12-pizza-box-kraft`) |
| `QUERY_STRING` | String | Query parameters (e.g., `utm_source=google`) |

**Used for Query Preservation**:
| Key | Type | Description |
|---|---|---|
| `QUERY_STRING` | String | Existing query params to merge with variant params |

### Output (Rack Response)

**Redirect Response** (when match found):
```ruby
[
  301,  # HTTP status code (Permanent Redirect)
  {
    'Location' => target_url,
    'Content-Type' => 'text/html',
    'Cache-Control' => 'public, max-age=86400'
  },
  ['Redirecting to new URL...']
]
```

**Pass-Through** (when no match):
```ruby
@app.call(env)  # Continue to next middleware/Rails router
```

### Database Interaction

**Query**:
```ruby
LegacyRedirect.active.find_by_path(normalized_path)
```

**Performance**:
- Single query per request
- Uses functional index on `LOWER(legacy_path)`
- Expected query time: <5ms

**Hit Counter Update** (non-blocking):
```ruby
redirect.record_hit!  # SQL: UPDATE ... SET hit_count = hit_count + 1
```

## Behavior Specifications

### Case Insensitivity

**Requirement**: URLs are matched case-insensitively

**Examples**:
| Request Path | Stored Path | Match? |
|---|---|---|
| `/product/pizza-box-kraft` | `/product/Pizza-Box-Kraft` | ✅ YES |
| `/product/PIZZA-BOX-KRAFT` | `/product/pizza-box-kraft` | ✅ YES |
| `/Product/Pizza-Box-Kraft` | `/product/pizza-box-kraft` | ❌ NO (path doesn't start with `/product/`) |

**Implementation**: Use `LOWER()` function in database query

### Trailing Slash Handling

**Requirement**: Handle URLs with/without trailing slashes consistently

**Examples**:
| Request Path | Stored Path | Match? |
|---|---|---|
| `/product/pizza-box-kraft/` | `/product/pizza-box-kraft` | ✅ YES |
| `/product/pizza-box-kraft` | `/product/pizza-box-kraft/` | ✅ YES |

**Implementation**: Strip trailing slash before lookup

### Query Parameter Preservation

**Requirement**: Preserve existing query parameters when redirecting

**Examples**:
| Legacy URL | Variant Params | Result URL |
|---|---|---|
| `/product/pizza-box?utm_source=google` | `{size: "12\""}` | `/products/pizza-box-kraft?size=12%22&utm_source=google` |
| `/product/hot-cup` | `{size: "8oz", colour: "White"}` | `/products/single-wall-paper-hot-cup?size=8oz&colour=White` |
| `/product/straws?ref=email` | `{}` | `/products/paper-straws?ref=email` |

**Implementation**:
```ruby
existing_params = Rack::Utils.parse_query(env['QUERY_STRING'])
all_params = variant_params.merge(existing_params)
query_string = Rack::Utils.build_query(all_params)
target_url = "/products/#{target_slug}?#{query_string}"
```

### HTTP Method Handling

**Requirement**: Only redirect GET requests (ignore POST, PUT, DELETE, etc.)

**Rationale**: Redirecting POST would lose form data, violating user expectations

**Examples**:
| Method | Path | Action |
|---|---|---|
| GET | `/product/pizza-box` | Redirect if match found |
| POST | `/product/pizza-box` | Pass through (no redirect) |
| HEAD | `/product/pizza-box` | Redirect if match found |
| PUT | `/product/pizza-box` | Pass through (no redirect) |

**Implementation**:
```ruby
return @app.call(env) unless %w[GET HEAD].include?(request.method)
```

### Active/Inactive Redirects

**Requirement**: Only redirect if `active: true`

**Behavior**:
- Active redirect → 301 redirect
- Inactive redirect → Pass through to Rails (results in 404)
- Deleted redirect → Pass through to Rails (results in 404)

**Implementation**: Use `LegacyRedirect.active` scope in query

### Error Handling

**Database Connection Error**:
```ruby
rescue ActiveRecord::ConnectionNotEstablished => e
  # Log error and pass through (fail open)
  Rails.logger.error("LegacyRedirectMiddleware: Database unavailable - #{e.message}")
  @app.call(env)
end
```

**Query Timeout**:
```ruby
rescue ActiveRecord::QueryAborted, ActiveRecord::StatementInvalid => e
  # Log error and pass through
  Rails.logger.error("LegacyRedirectMiddleware: Query error - #{e.message}")
  @app.call(env)
end
```

**Rationale**: Fail open (pass request through) to prevent middleware from breaking the entire application

## Performance Contract

**Timing Requirements**:
- Middleware execution: <10ms per request
- Database lookup: <5ms (with proper indexing)
- Total overhead: <15ms per legacy URL request

**Scalability**:
- Handles concurrent requests safely (SQL increment is atomic)
- No in-memory state (stateless middleware)
- Database connection pooling handled by Rails

**Optimization Opportunities** (future):
- In-memory cache (Redis) for redirect mappings
- Cache TTL: 5 minutes (balances freshness and performance)
- Cache invalidation on redirect updates

## Security Contract

**Path Validation**:
- Only intercept `/product/*` paths (ignore all other paths)
- No regex injection risk (string prefix match only)
- No path traversal risk (database lookup, not file system)

**SQL Injection Prevention**:
- Use ActiveRecord parameter binding (prevents SQL injection)
- No raw SQL queries

**DoS Protection**:
- Fail fast on database errors (pass through instead of retry loop)
- No recursive redirects (single hop only)
- Cache-Control header prevents excessive lookups

**CSRF Protection**:
- Not applicable (GET requests only, no state changes except hit counter)

## Testing Contract

**Unit Tests** (`test/middleware/legacy_redirect_middleware_test.rb`):

1. **Match Found (Active)**
   - Given: Active redirect exists for `/product/pizza-box`
   - When: GET request to `/product/pizza-box`
   - Then: Return 301 with correct Location header

2. **Match Found (Inactive)**
   - Given: Inactive redirect exists for `/product/old-item`
   - When: GET request to `/product/old-item`
   - Then: Pass through to next middleware (no redirect)

3. **No Match Found**
   - Given: No redirect exists for `/product/unknown`
   - When: GET request to `/product/unknown`
   - Then: Pass through to next middleware (results in 404)

4. **Case Insensitive Match**
   - Given: Redirect exists for `/product/pizza-box`
   - When: GET request to `/product/PIZZA-BOX`
   - Then: Return 301 redirect

5. **Trailing Slash Handling**
   - Given: Redirect exists for `/product/pizza-box`
   - When: GET request to `/product/pizza-box/`
   - Then: Return 301 redirect

6. **Query Parameter Preservation**
   - Given: Redirect with variant params `{size: "12"}`
   - When: GET request to `/product/pizza-box?utm_source=google`
   - Then: Redirect to `/products/pizza-box-kraft?size=12&utm_source=google`

7. **Non-GET Request**
   - Given: Active redirect exists
   - When: POST request to `/product/pizza-box`
   - Then: Pass through (no redirect)

8. **Non-Product Path**
   - Given: Active redirect exists for `/product/pizza-box`
   - When: GET request to `/categories/pizza-boxes`
   - Then: Pass through (no interception)

9. **Hit Counter Increment**
   - Given: Active redirect with `hit_count: 5`
   - When: GET request triggers redirect
   - Then: `hit_count` incremented to 6

10. **Database Error Handling**
    - Given: Database is unavailable
    - When: GET request to `/product/pizza-box`
    - Then: Pass through (fail open, log error)

**Integration Tests** (`test/integration/legacy_redirect_flow_test.rb`):

1. **End-to-End Redirect**
   - Create redirect in database
   - Make HTTP request to legacy URL
   - Assert 301 status and correct Location header
   - Assert hit counter incremented

2. **Full Flow with Variant Selection**
   - Create redirect with variant params
   - Make HTTP request with existing query params
   - Assert redirected to product page
   - Assert variant parameters in URL
   - Assert existing query params preserved

**System Tests** (`test/system/legacy_redirect_system_test.rb`):

1. **Browser Redirect**
   - Visit legacy URL in browser (Capybara)
   - Assert browser redirected to new URL
   - Assert correct product page displayed
   - Assert variant pre-selected (if applicable)

## Example Implementation

**File**: `app/middleware/legacy_redirect_middleware.rb`

```ruby
class LegacyRedirectMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    # Only intercept GET/HEAD requests to /product/* paths
    return @app.call(env) unless %w[GET HEAD].include?(request.method)
    return @app.call(env) unless request.path.start_with?('/product/')

    # Normalize path and lookup redirect
    normalized_path = normalize_path(request.path)
    redirect = LegacyRedirect.active.find_by_path(normalized_path)

    # Pass through if no active redirect found
    return @app.call(env) unless redirect

    # Increment hit counter (async, non-blocking)
    increment_hit_counter(redirect)

    # Build target URL with preserved query parameters
    target_url = build_target_url(redirect, request)

    # Return 301 redirect
    [301, redirect_headers(target_url), ['Redirecting...']]
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid => e
    Rails.logger.error("LegacyRedirectMiddleware: #{e.class} - #{e.message}")
    @app.call(env)  # Fail open
  end

  private

  def normalize_path(path)
    path.chomp('/')  # Remove trailing slash
  end

  def increment_hit_counter(redirect)
    # Non-blocking increment (fire and forget)
    redirect.record_hit!
  rescue => e
    Rails.logger.warn("LegacyRedirectMiddleware: Hit counter update failed - #{e.message}")
  end

  def build_target_url(redirect, request)
    url = redirect.target_url  # /products/{slug}?size=X&colour=Y

    # Merge with existing query parameters
    if request.query_string.present?
      existing_params = Rack::Utils.parse_query(request.query_string)
      variant_params = redirect.variant_params || {}
      all_params = variant_params.merge(existing_params)
      query_string = Rack::Utils.build_query(all_params)
      url = "/products/#{redirect.target_slug}?#{query_string}"
    end

    url
  end

  def redirect_headers(location)
    {
      'Location' => location,
      'Content-Type' => 'text/html; charset=utf-8',
      'Cache-Control' => 'public, max-age=86400'  # Cache for 24 hours
    }
  end
end
```

## Summary

**Middleware**: `LegacyRedirectMiddleware`
**Position**: Early in Rack stack (after session, before routing)
**Scope**: `/product/*` paths only (GET/HEAD methods)
**Behavior**: Case-insensitive, trailing-slash tolerant, query-preserving
**Performance**: <15ms overhead, single database query
**Security**: SQL injection safe, DoS resistant, fail-open on errors
**Testing**: 10 unit tests, 2 integration tests, 1 system test
