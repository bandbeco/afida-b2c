# API Contract: Outrank Webhook Endpoint

**Feature**: 017-outrank-webhook
**Date**: 2026-01-14
**Version**: 1.0.0

## Endpoint

```
POST /api/webhooks/outrank
```

## Authentication

**Type**: Bearer Token

**Header**: `Authorization: Bearer {access_token}`

**Token Source**: Configured in Rails credentials at `outrank.access_token`

**Error Response** (401 Unauthorized):
```json
{
  "error": "Unauthorized",
  "message": "Invalid or missing access token"
}
```

---

## Request

### Headers

| Header | Required | Value |
|--------|----------|-------|
| `Content-Type` | Yes | `application/json` |
| `Authorization` | Yes | `Bearer {access_token}` |

### Body Schema

```json
{
  "event_type": "publish_articles",
  "timestamp": "2026-01-14T12:00:00Z",
  "data": {
    "articles": [
      {
        "id": "string (required)",
        "title": "string (required)",
        "slug": "string (required)",
        "content_markdown": "string (required)",
        "content_html": "string (optional, ignored)",
        "meta_description": "string (optional)",
        "image_url": "string (optional, URL)",
        "created_at": "string (ISO 8601)",
        "tags": ["string"]
      }
    ]
  }
}
```

### Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `event_type` | string | Yes | Always `"publish_articles"` |
| `timestamp` | string | Yes | ISO 8601 timestamp of event |
| `data.articles` | array | Yes | Array of article objects |
| `data.articles[].id` | string | Yes | Unique Outrank identifier |
| `data.articles[].title` | string | Yes | Article title |
| `data.articles[].slug` | string | Yes | URL-friendly slug |
| `data.articles[].content_markdown` | string | Yes | Article body in Markdown |
| `data.articles[].content_html` | string | No | HTML version (ignored) |
| `data.articles[].meta_description` | string | No | SEO meta description |
| `data.articles[].image_url` | string | No | Cover image URL |
| `data.articles[].created_at` | string | No | Article creation timestamp |
| `data.articles[].tags` | array | No | Array of tag strings |

### Example Request

```bash
curl -X POST https://afida.com/api/webhooks/outrank \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_access_token" \
  -d '{
    "event_type": "publish_articles",
    "timestamp": "2026-01-14T15:30:00Z",
    "data": {
      "articles": [
        {
          "id": "abc123",
          "title": "Eco-Friendly Packaging for Cafes",
          "slug": "eco-friendly-packaging-for-cafes",
          "content_markdown": "# Introduction\n\nSustainable packaging choices...",
          "meta_description": "Learn about eco-friendly packaging options for your cafe",
          "image_url": "https://outrank.so/images/eco-packaging.jpg",
          "created_at": "2026-01-14T14:00:00Z",
          "tags": ["sustainability", "cafes", "packaging"]
        }
      ]
    }
  }'
```

---

## Response

### Success Response (200 OK)

Returned when webhook is processed (even if some articles fail).

```json
{
  "status": "success",
  "processed": 2,
  "results": [
    {
      "outrank_id": "abc123",
      "status": "created",
      "blog_post_id": 42
    },
    {
      "outrank_id": "def456",
      "status": "skipped",
      "reason": "duplicate"
    }
  ]
}
```

### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | Overall status: `"success"` or `"partial"` |
| `processed` | integer | Number of articles in request |
| `results` | array | Per-article processing results |
| `results[].outrank_id` | string | Outrank article identifier |
| `results[].status` | string | `"created"`, `"skipped"`, or `"error"` |
| `results[].blog_post_id` | integer | Created BlogPost ID (if created) |
| `results[].reason` | string | Reason for skip/error (if applicable) |

### Error Responses

**401 Unauthorized** - Invalid or missing token
```json
{
  "error": "Unauthorized",
  "message": "Invalid or missing access token"
}
```

**400 Bad Request** - Malformed JSON or missing required fields
```json
{
  "error": "Bad Request",
  "message": "Missing required field: data.articles"
}
```

**422 Unprocessable Entity** - Validation errors
```json
{
  "error": "Unprocessable Entity",
  "message": "Article validation failed",
  "details": {
    "outrank_id": "abc123",
    "errors": ["Title can't be blank", "Slug has invalid format"]
  }
}
```

**500 Internal Server Error** - Unexpected error
```json
{
  "error": "Internal Server Error",
  "message": "An unexpected error occurred"
}
```

---

## Status Codes Summary

| Code | Meaning | When Used |
|------|---------|-----------|
| 200 | OK | Webhook processed successfully |
| 400 | Bad Request | Malformed JSON or missing required fields |
| 401 | Unauthorized | Invalid or missing Bearer token |
| 422 | Unprocessable Entity | Validation errors on article data |
| 500 | Internal Server Error | Unexpected server error |

---

## Idempotency

The endpoint is **idempotent** based on the `outrank_id` field:

- If an article with the same `outrank_id` exists, it is **skipped** (not updated)
- Response includes `status: "skipped"` with `reason: "duplicate"`
- This allows Outrank to safely retry failed webhook deliveries

---

## Rate Limiting

No explicit rate limiting implemented. Outrank is a trusted source with expected volume of 1-10 articles per day.

---

## Testing

### Test Webhook in Development

1. Start Rails server: `bin/dev`
2. Use curl or Postman with test token from credentials
3. Verify BlogPost created in admin at `/admin/blog_posts`

### Test Token Setup

```bash
# Edit credentials
rails credentials:edit

# Add:
outrank:
  access_token: "test-token-for-development"
```
