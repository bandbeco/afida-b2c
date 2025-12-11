# Afida.com Production Launch Checklist

This checklist covers everything needed to launch afida.com in production for the first time.

---

## PRE-LAUNCH CHECKLIST

### 1. Domain & DNS Configuration
- [ ] **Register/configure afida.com domain**
- [ ] **Set up DNS records:**
  - [ ] A record pointing to web server IP: `195.201.16.125`
  - [ ] Consider www subdomain redirect
- [ ] **Configure SSL/TLS via Let's Encrypt** (handled by Kamal proxy)

### 2. Code Changes Required

#### 2.1 Update Domain References (CRITICAL)
- [ ] **Update `config/deploy.yml`:**
  - [ ] Line 22: Change `host: kiyuro.com` → `host: afida.com`
  - [ ] Line 43: Change `APP_HOST: kiyuro.com` → `APP_HOST: afida.com`

- [ ] **Update `app/controllers/robots_controller.rb`:**
  - [ ] Line 15: Either remove kiyuro.com from `STAGING_DOMAINS` array, or repurpose for actual staging domain

- [ ] **Update `app/views/layouts/application.html.erb`:**
  - [ ] Line 8: Remove or update the `kiyuro.com` noindex condition (this blocks search indexing!)

### 3. Credentials Configuration

Edit credentials with: `rails credentials:edit`

#### 3.1 Required Credentials
- [ ] **`application.domain`** - Set to `afida.com`
- [ ] **`stripe.publishable_key`** - Production Stripe publishable key (pk_live_...)
- [ ] **`stripe.secret_key`** - Production Stripe secret key (sk_live_...)
- [ ] **`mailgun.api_key`** - Production Mailgun API key
- [ ] **`mailgun.domain`** - Verified Mailgun domain for afida.com

#### 3.2 Storage & Media
- [ ] **`hetzner.access_key`** - Hetzner Object Storage access key
- [ ] **`hetzner.secret_key`** - Hetzner Object Storage secret key
- [ ] Verify bucket `afida-b2c` exists and is accessible

#### 3.3 Monitoring (Recommended)
- [ ] **`sentry.dsn`** - Sentry DSN for error tracking

#### 3.4 SEO & Business
- [ ] **`google_business.rating`** - Google Business rating (e.g., "4.8")
- [ ] **`google_business.review_count`** - Number of reviews
- [ ] **`google_business.profile_url`** - Full URL to Google Business Profile
- [ ] **`google_business.place_id`** - Google Place ID

### 4. Environment Secrets (Kamal)

Configure in `.kamal/secrets`:
- [ ] **`RAILS_MASTER_KEY`** - Rails master key for decrypting credentials
- [ ] **`POSTGRES_PASSWORD`** - Production database password
- [ ] **`KAMAL_REGISTRY_PASSWORD`** - Docker Hub access token

### 5. Third-Party Service Setup

#### 5.1 Stripe
- [ ] Switch to live mode in Stripe Dashboard
- [ ] Configure webhook endpoint: `https://afida.com/webhooks/stripe`
- [ ] Add webhook signing secret to credentials
- [ ] Verify products/prices are configured in Stripe
- [ ] Test checkout flow with live cards

#### 5.2 Mailgun
- [ ] Verify afida.com domain in Mailgun (DNS TXT records)
- [ ] Configure DKIM, SPF, and DMARC records
- [ ] Set up bounce/complaint handling
- [ ] Test email delivery (order confirmation, registration)

#### 5.3 Hetzner Object Storage
- [ ] Verify bucket `afida-b2c` is created
- [ ] Verify CORS settings allow afida.com origin
- [ ] Test image upload/retrieval
- [ ] Migrate existing product images if needed

#### 5.4 Google Tag Manager
- [ ] Verify GTM container `GTM-NCN4DWXN` is configured for afida.com
- [ ] Or create new container and update `config/initializers/google_tag_manager.rb`
- [ ] Set up Google Analytics 4 property

### 6. Database Setup
- [ ] Ensure PostgreSQL server (188.34.197.99) is accessible from web server
- [ ] Create production databases:
  - [ ] `shop_production` (main database)
  - [ ] `shop_production_cache` (Solid Cache)
  - [ ] `shop_production_queue` (Solid Queue)
  - [ ] `shop_production_cable` (Solid Cable)
- [ ] Run migrations: `kamal app exec 'bin/rails db:prepare'`
- [ ] Seed production data if needed

### 7. Security Review
- [ ] **Admin Authentication:** Ensure admin area (`/admin`) requires authentication
- [ ] **Host Authorization:** Consider enabling in `config/environments/production.rb`:
  ```ruby
  config.hosts = ["afida.com", "www.afida.com"]
  ```
- [ ] **Review CORS settings** for Active Storage
- [ ] **Check rate limiting** (if implemented)
- [ ] **Run Brakeman security scan:** `brakeman`

### 8. SEO & Analytics
- [ ] Verify sitemap generates correctly: `https://afida.com/sitemap.xml`
- [ ] Verify robots.txt is correct: `https://afida.com/robots.txt`
- [ ] Test structured data with [Google Rich Results Test](https://search.google.com/test/rich-results)
- [ ] Set up Google Search Console for afida.com
- [ ] Submit sitemap to Google Search Console
- [ ] Set up Bing Webmaster Tools (optional)

### 9. Content & Data
- [ ] Verify all products have required fields:
  - [ ] Descriptions (short, standard, detailed)
  - [ ] Photos (product photo, lifestyle photo)
  - [ ] Meta titles and descriptions
  - [ ] Active variants with prices and stock
- [ ] Verify all categories have meta_title and meta_description
- [ ] Run SEO validation: `rails seo:validate`
- [ ] Verify Google Merchant feed: `https://afida.com/feeds/google-merchant.xml`

### 10. Performance & Caching
- [ ] Verify Solid Cache is working
- [ ] Verify Solid Queue is processing jobs
- [ ] Check asset caching headers
- [ ] Test page load times

### 11. Final Pre-Launch Tests
- [ ] **Full checkout flow** with live Stripe
- [ ] **Email delivery** (order confirmation, registration)
- [ ] **Image loading** from Hetzner storage
- [ ] **Mobile responsiveness**
- [ ] **Cross-browser testing** (Chrome, Safari, Firefox, Edge)
- [ ] **Guest cart** functionality
- [ ] **User registration/login**
- [ ] **Sample ordering** functionality

---

## DEPLOYMENT

### Deploy Command
```bash
bin/kamal deploy
```

### First Deployment Steps
1. Build and push Docker image
2. Start database accessory (if not running)
3. Run database migrations
4. Start web server
5. Configure SSL certificate via Let's Encrypt

---

## POST-LAUNCH CHECKLIST

### Immediate (First 30 Minutes)

#### 1. Smoke Tests
- [ ] Verify site loads at `https://afida.com`
- [ ] Verify SSL certificate is valid
- [ ] Verify all pages load without errors
- [ ] Verify images load correctly
- [ ] Verify cart functionality works
- [ ] Verify checkout initiates properly

#### 2. Monitoring
- [ ] Check Sentry for errors
- [ ] Check Rails logs: `kamal app logs -f`
- [ ] Monitor server resources (CPU, memory, disk)

#### 3. Test Order
- [ ] **Place a real test order** (can refund later)
- [ ] Verify order confirmation email received
- [ ] Verify order appears in admin
- [ ] Verify Stripe payment recorded

### First Day

#### 4. SEO Verification
- [ ] Verify Google can crawl site (no noindex issues)
- [ ] Request indexing in Google Search Console
- [ ] Verify sitemap is being processed
- [ ] Check robots.txt is allowing crawlers

#### 5. Analytics
- [ ] Verify Google Analytics tracking
- [ ] Verify GTM is firing correctly
- [ ] Set up conversion tracking for purchases

#### 6. Email Deliverability
- [ ] Check email bounce rates
- [ ] Verify emails not landing in spam
- [ ] Test from multiple email providers (Gmail, Outlook, etc.)

### First Week

#### 7. Performance Monitoring
- [ ] Monitor page load times
- [ ] Check for slow database queries
- [ ] Monitor background job performance
- [ ] Set up uptime monitoring (e.g., UptimeRobot, Pingdom)

#### 8. Search Console Review
- [ ] Check for crawl errors
- [ ] Review Core Web Vitals
- [ ] Check mobile usability
- [ ] Review coverage report

#### 9. User Feedback
- [ ] Monitor for customer issues
- [ ] Check contact form submissions
- [ ] Review error tracking for patterns

### First Month

#### 10. SEO & Marketing
- [ ] Submit to Google Merchant Center
- [ ] Set up Google Shopping campaigns (if planned)
- [ ] Build backlinks
- [ ] Monitor keyword rankings

#### 11. Business Operations
- [ ] Establish order fulfillment workflow
- [ ] Set up inventory alerts
- [ ] Configure order notifications
- [ ] Train team on admin interface

#### 12. Security & Maintenance
- [ ] Schedule regular backups
- [ ] Plan update/maintenance windows
- [ ] Review and rotate credentials if needed
- [ ] Plan for scaling (if needed)

---

## QUICK REFERENCE

### Key URLs
- **Site:** https://afida.com
- **Admin:** https://afida.com/admin
- **Health Check:** https://afida.com/up
- **Sitemap:** https://afida.com/sitemap.xml
- **Robots.txt:** https://afida.com/robots.txt
- **Google Merchant Feed:** https://afida.com/feeds/google-merchant.xml

### Kamal Commands
```bash
# Deploy
bin/kamal deploy

# View logs
bin/kamal app logs -f

# Rails console
bin/kamal console

# Shell access
bin/kamal shell

# Database console
bin/kamal dbc

# Rollback
bin/kamal rollback
```

### Server Details
- **Web Server:** 195.201.16.125
- **Database Server:** 188.34.197.99:5432

### Credentials
```bash
# Edit credentials
rails credentials:edit

# Show credentials (requires RAILS_MASTER_KEY)
rails credentials:show
```

---

## ROLLBACK PLAN

If critical issues are discovered post-launch:

1. **Quick Fix:** If issue is minor code fix
   - Fix locally, commit, `bin/kamal deploy`

2. **Rollback:** If previous version was stable
   - `bin/kamal rollback`

3. **Maintenance Mode:** If extensive debugging needed
   - Take site offline temporarily
   - Fix issues
   - Redeploy

4. **Database Rollback:** If data corruption
   - Restore from backup
   - Verify data integrity
   - Redeploy

---

## CONTACTS & RESOURCES

### Support Links
- **Stripe Dashboard:** https://dashboard.stripe.com
- **Mailgun Dashboard:** https://app.mailgun.com
- **Hetzner Console:** https://console.hetzner.cloud
- **Sentry Dashboard:** https://sentry.io
- **Google Search Console:** https://search.google.com/search-console
- **Google Analytics:** https://analytics.google.com

### Documentation
- **Rails Guides:** https://guides.rubyonrails.org
- **Kamal Docs:** https://kamal-deploy.org
- **Stripe API:** https://stripe.com/docs/api
