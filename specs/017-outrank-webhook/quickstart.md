# Quickstart: Outrank Webhook Integration

**Feature**: 017-outrank-webhook
**Date**: 2026-01-14

## Overview

This feature adds a webhook endpoint that receives blog articles from Outrank.so's SEO content platform. Articles are automatically imported as drafts for admin review.

---

## Prerequisites

- [x] Blog foundation implemented (`BlogPost`, `BlogCategory` models)
- [x] Active Storage configured for image attachments
- [ ] Outrank account with webhook integration configured

---

## Quick Setup

### 1. Run Migration

```bash
rails db:migrate
```

This adds the `outrank_id` column to `blog_posts` for idempotency.

### 2. Add Access Token to Credentials

```bash
rails credentials:edit
```

Add the token you configured in Outrank's dashboard:

```yaml
outrank:
  access_token: "your-token-from-outrank-dashboard"
```

### 3. Add HTTP Gem (if not present)

```bash
bundle add http
```

### 4. Configure Outrank Dashboard

In Outrank (dashboard/integrations/docs/webhook):

1. **Integration Name**: "Afida Blog"
2. **Webhook Endpoint**: `https://afida.com/api/webhooks/outrank`
3. **Access Token**: Same token you added to Rails credentials

---

## Testing Locally

### 1. Start Development Server

```bash
bin/dev
```

### 2. Test with cURL

```bash
curl -X POST http://localhost:3000/api/webhooks/outrank \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-test-token" \
  -d '{
    "event_type": "publish_articles",
    "timestamp": "2026-01-14T12:00:00Z",
    "data": {
      "articles": [{
        "id": "test-123",
        "title": "Test Article from Outrank",
        "slug": "test-article-from-outrank",
        "content_markdown": "# Hello World\n\nThis is a test article.",
        "meta_description": "A test article",
        "tags": ["test"]
      }]
    }
  }'
```

### 3. Verify Article Created

```bash
rails console
BlogPost.find_by(outrank_id: "test-123")
```

Or visit `/admin/blog_posts` in your browser.

---

## Key Files

| File | Purpose |
|------|---------|
| `app/controllers/api/webhooks/outrank_controller.rb` | Webhook endpoint |
| `app/services/outrank/webhook_processor.rb` | Main processing logic |
| `app/services/outrank/article_importer.rb` | Single article import |
| `app/services/outrank/image_downloader.rb` | Cover image download |
| `config/routes.rb` | Route definition |
| `db/migrate/xxx_add_outrank_id_to_blog_posts.rb` | Schema change |

---

## How It Works

```
1. Outrank publishes article
           │
           ▼
2. POST /api/webhooks/outrank
           │
           ▼
3. Verify Bearer token ──────────▶ 401 if invalid
           │
           ▼
4. Parse JSON payload
           │
           ▼
5. For each article in batch:
   ├── Check for duplicate (outrank_id)
   ├── Find/create category from first tag
   ├── Create BlogPost (published: false)
   ├── Download & attach cover image
   └── Return result
           │
           ▼
6. Return aggregate response
```

---

## Common Tasks

### Check Imported Articles

```ruby
# In rails console
BlogPost.where.not(outrank_id: nil)
```

### Re-process Failed Image

```ruby
post = BlogPost.find_by(outrank_id: "abc123")
Outrank::ImageDownloader.new(post, "https://example.com/image.jpg").call
```

### Publish Imported Article

```ruby
post = BlogPost.find_by(outrank_id: "abc123")
post.update!(published: true)
```

Or use the admin interface at `/admin/blog_posts`.

---

## Troubleshooting

### 401 Unauthorized

- Check `Authorization` header format: `Bearer {token}`
- Verify token matches `Rails.application.credentials.dig(:outrank, :access_token)`

### Article Not Created

- Check Rails logs for validation errors
- Ensure `title`, `content_markdown`, `slug`, and `id` are present
- Verify slug format matches `/\A[a-z0-9-]+\z/`

### Image Not Attached

- Check Rails logs for download errors
- Verify `image_url` is a valid, accessible URL
- Image download failures don't block article creation

### Duplicate Articles

- Intentional behavior - same `outrank_id` is skipped
- Response will show `status: "skipped", reason: "duplicate"`

---

## Production Checklist

- [ ] Migration deployed
- [ ] Production credentials configured with Outrank access token
- [ ] HTTPS enabled (Outrank requires HTTPS)
- [ ] Outrank dashboard configured with production webhook URL
- [ ] Test webhook from Outrank dashboard
- [ ] Monitor Rails logs for first few days
