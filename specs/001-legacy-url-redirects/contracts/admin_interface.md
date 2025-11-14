# Admin Interface Contract: Legacy Redirects Management

**Feature**: 001-legacy-url-redirects
**Date**: 2025-11-13
**Type**: Rails REST Controller

## Purpose

Defines the HTTP interface for the admin interface to manage legacy URL redirects. This is NOT a public API - it's a standard Rails controller with HTML views for authenticated administrators.

## Base URL

```
/admin/legacy_redirects
```

## Authentication

All endpoints require admin authentication (existing `/admin` authentication pattern).

**Authentication Method**: Session-based (Rails 8 built-in authentication)
**Authorization**: Current user must have admin role
**Redirect on Unauthorized**: `/` (root path) with alert message

## Endpoints

### 1. List All Redirects

**Endpoint**: `GET /admin/legacy_redirects`
**Purpose**: Display all redirect mappings with statistics and filters

**Request**:
- **Method**: GET
- **Path**: `/admin/legacy_redirects`
- **Query Parameters** (optional):
  | Parameter | Type | Description | Default |
  |---|---|---|---|
  | `status` | string | Filter by status: "active", "inactive", "all" | "all" |
  | `sort` | string | Sort order: "most_used", "recent", "alphabetical" | "most_used" |
  | `page` | integer | Page number for pagination | 1 |

**Response**: HTML page (not JSON)
- **Success**: 200 OK with HTML view
- **Content**: Table of redirects with columns:
  - Legacy Path
  - Target Product
  - Variant Parameters
  - Hit Count
  - Active Status
  - Actions (Edit, Delete, Test)

**Example URL**: `/admin/legacy_redirects?status=active&sort=most_used`

---

### 2. Show Redirect Details

**Endpoint**: `GET /admin/legacy_redirects/:id`
**Purpose**: Display detailed information for a single redirect

**Request**:
- **Method**: GET
- **Path**: `/admin/legacy_redirects/:id`
- **Path Parameters**:
  | Parameter | Type | Description |
  |---|---|---|
  | `id` | integer | Redirect ID |

**Response**: HTML page
- **Success**: 200 OK with redirect details
- **Not Found**: 404 with error message
- **Content**: Displays:
  - Full redirect configuration
  - Usage statistics (hit count, last hit timestamp if implemented)
  - Test functionality (preview redirect)

**Example URL**: `/admin/legacy_redirects/42`

---

### 3. New Redirect Form

**Endpoint**: `GET /admin/legacy_redirects/new`
**Purpose**: Display form to create a new redirect mapping

**Request**:
- **Method**: GET
- **Path**: `/admin/legacy_redirects/new`

**Response**: HTML form
- **Success**: 200 OK with form fields:
  - Legacy Path (text input, required)
  - Target Product Slug (autocomplete dropdown, required)
  - Variant Parameters (dynamic JSON editor or key-value inputs)
  - Active (checkbox, default: checked)
  - Test button (validates before save)

**Example URL**: `/admin/legacy_redirects/new`

---

### 4. Create Redirect

**Endpoint**: `POST /admin/legacy_redirects`
**Purpose**: Create a new redirect mapping

**Request**:
- **Method**: POST
- **Path**: `/admin/legacy_redirects`
- **Content-Type**: `application/x-www-form-urlencoded` (Rails form submission)
- **Form Parameters**:
  | Parameter | Type | Required | Description |
  |---|---|---|---|
  | `legacy_redirect[legacy_path]` | string | Yes | Legacy URL path (e.g., `/product/12-pizza-box`) |
  | `legacy_redirect[target_slug]` | string | Yes | Product slug (e.g., `pizza-box-kraft`) |
  | `legacy_redirect[variant_params]` | json | No | Variant parameters as JSON string |
  | `legacy_redirect[active]` | boolean | No | Whether redirect is active (default: true) |

**Response**:
- **Success (201 Created)**:
  - Redirect to: `/admin/legacy_redirects/:id`
  - Flash message: "Redirect created successfully"
- **Validation Error (422 Unprocessable Entity)**:
  - Re-render form with errors
  - Display validation errors inline
  - Preserve submitted values

**Example Request Body** (form-encoded):
```
legacy_redirect[legacy_path]=/product/12-pizza-box-kraft
legacy_redirect[target_slug]=pizza-box-kraft
legacy_redirect[variant_params]={"size":"12\""}
legacy_redirect[active]=1
```

---

### 5. Edit Redirect Form

**Endpoint**: `GET /admin/legacy_redirects/:id/edit`
**Purpose**: Display form to edit existing redirect

**Request**:
- **Method**: GET
- **Path**: `/admin/legacy_redirects/:id/edit`
- **Path Parameters**:
  | Parameter | Type | Description |
  |---|---|---|
  | `id` | integer | Redirect ID |

**Response**: HTML form (pre-filled with current values)
- **Success**: 200 OK with form
- **Not Found**: 404 if redirect doesn't exist

**Example URL**: `/admin/legacy_redirects/42/edit`

---

### 6. Update Redirect

**Endpoint**: `PATCH /admin/legacy_redirects/:id`
**Purpose**: Update existing redirect mapping

**Request**:
- **Method**: PATCH (or PUT)
- **Path**: `/admin/legacy_redirects/:id`
- **Path Parameters**:
  | Parameter | Type | Description |
  |---|---|---|
  | `id` | integer | Redirect ID |
- **Form Parameters**: Same as Create (all optional for PATCH)

**Response**:
- **Success (200 OK)**:
  - Redirect to: `/admin/legacy_redirects/:id`
  - Flash message: "Redirect updated successfully"
- **Validation Error (422)**:
  - Re-render edit form with errors
- **Not Found (404)**:
  - Redirect to index with error message

---

### 7. Delete Redirect

**Endpoint**: `DELETE /admin/legacy_redirects/:id`
**Purpose**: Delete (hard delete) redirect mapping

**Request**:
- **Method**: DELETE
- **Path**: `/admin/legacy_redirects/:id`
- **Path Parameters**:
  | Parameter | Type | Description |
  |---|---|---|
  | `id` | integer | Redirect ID |

**Response**:
- **Success (200 OK)**:
  - Redirect to: `/admin/legacy_redirects`
  - Flash message: "Redirect deleted successfully"
- **Not Found (404)**:
  - Redirect to index with error message

**Note**: Consider implementing soft delete (set `active: false`) instead of hard delete to preserve analytics.

---

### 8. Toggle Active Status

**Endpoint**: `PATCH /admin/legacy_redirects/:id/toggle`
**Purpose**: Quickly activate/deactivate redirect without full edit

**Request**:
- **Method**: PATCH
- **Path**: `/admin/legacy_redirects/:id/toggle`
- **Path Parameters**:
  | Parameter | Type | Description |
  |---|---|---|
  | `id` | integer | Redirect ID |

**Response**:
- **Success (200 OK)**:
  - Redirect to: `/admin/legacy_redirects`
  - Flash message: "Redirect activated" or "Redirect deactivated"
- **Not Found (404)**:
  - Redirect to index with error message

---

### 9. Test Redirect

**Endpoint**: `GET /admin/legacy_redirects/:id/test`
**Purpose**: Preview redirect behavior without modifying hit count

**Request**:
- **Method**: GET
- **Path**: `/admin/legacy_redirects/:id/test`
- **Path Parameters**:
  | Parameter | Type | Description |
  |---|---|---|
  | `id` | integer | Redirect ID |

**Response**:
- **Success (200 OK)**:
  - Display test results:
    - Source URL: `/product/12-pizza-box-kraft`
    - Target URL: `/products/pizza-box-kraft?size=12"`
    - HTTP Status: 301
    - Variant match status
  - **Button**: "Test in Browser" (opens new tab to actual redirect)
- **Not Found (404)**:
  - Error message

---

### 10. Bulk Import

**Endpoint**: `POST /admin/legacy_redirects/import`
**Purpose**: Import multiple redirects from JSON or CSV file

**Request**:
- **Method**: POST
- **Path**: `/admin/legacy_redirects/import`
- **Content-Type**: `multipart/form-data`
- **Form Parameters**:
  | Parameter | Type | Required | Description |
  |---|---|---|---|
  | `file` | file | Yes | JSON or CSV file containing redirects |
  | `overwrite` | boolean | No | Overwrite existing redirects (default: false) |

**Response**:
- **Success (200 OK)**:
  - Redirect to index
  - Flash message: "Imported 42 redirects (5 errors)"
  - Display error details if any
- **Validation Error (422)**:
  - Show file format errors
  - Do not create partial imports (transaction rollback)

**File Format** (JSON):
```json
[
  {
    "legacy_path": "/product/12-pizza-box-kraft",
    "target_slug": "pizza-box-kraft",
    "variant_params": {"size": "12\""},
    "active": true
  },
  {
    "legacy_path": "/product/8oz-hot-cup-white",
    "target_slug": "single-wall-paper-hot-cup",
    "variant_params": {"size": "8oz", "colour": "White"},
    "active": true
  }
]
```

---

## Routes Configuration

**File**: `config/routes.rb`

```ruby
namespace :admin do
  resources :legacy_redirects do
    member do
      patch :toggle      # Toggle active/inactive
      get :test          # Test redirect behavior
    end
    collection do
      post :import       # Bulk import
    end
  end
end
```

**Generated Routes**:
```
GET    /admin/legacy_redirects              # index
GET    /admin/legacy_redirects/new          # new
POST   /admin/legacy_redirects              # create
GET    /admin/legacy_redirects/:id          # show
GET    /admin/legacy_redirects/:id/edit     # edit
PATCH  /admin/legacy_redirects/:id          # update
DELETE /admin/legacy_redirects/:id          # destroy
PATCH  /admin/legacy_redirects/:id/toggle   # toggle
GET    /admin/legacy_redirects/:id/test     # test
POST   /admin/legacy_redirects/import       # import
```

## Error Handling

**Validation Errors** (422 Unprocessable Entity):
```ruby
{
  errors: {
    legacy_path: ["can't be blank", "has already been taken"],
    target_slug: ["can't be blank", "product not found"]
  }
}
```

**Not Found** (404):
- Redirect to index with flash message: "Redirect not found"

**Unauthorized** (401):
- Redirect to root with flash message: "You must be an admin to access this page"

**Server Error** (500):
- Display generic error page
- Log error details for debugging

## Security Considerations

**CSRF Protection**: Enabled for all POST/PATCH/DELETE requests (Rails default)
**SQL Injection**: Prevented by ActiveRecord parameter binding
**XSS**: Prevented by ERB escaping (Rails default)
**Path Traversal**: Validated legacy_path format (must start with `/product/`)
**Input Validation**: All parameters validated before database insertion

## Performance Considerations

**Pagination**: Index page uses pagination (25 redirects per page)
**Eager Loading**: Not needed (no associations)
**Caching**: Not needed (admin interface, low traffic)
**Database Queries**: Single query per action (no N+1 possible)

## Testing Contract

**Controller Tests** (Minitest):
- Test each endpoint with valid/invalid data
- Test authentication enforcement
- Test authorization (admin-only)
- Test error handling (404, 422, 500)

**Integration Tests**:
- Test full workflows (create → edit → toggle → delete)
- Test bulk import functionality
- Test redirect testing feature

**System Tests**:
- Test admin UI flows in browser
- Test form validation feedback
- Test redirect preview functionality

## Summary

**Controller**: `Admin::LegacyRedirectsController`
**Endpoints**: 10 (standard CRUD + 3 custom actions)
**Authentication**: Required (admin session)
**Response Format**: HTML (Rails views)
**Routes Namespace**: `/admin/legacy_redirects`
**Security**: CSRF, input validation, admin authorization
