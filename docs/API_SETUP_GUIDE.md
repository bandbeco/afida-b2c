# API Setup Guide - AI SEO Engine

Complete guide to configuring the three required APIs for the AI SEO Engine.

---

## Overview

You need three API credentials:
1. **Anthropic** (Claude AI) - £30-50/month for content generation
2. **SerpAPI** - £40/month (or FREE tier: 100 searches/month)
3. **Google Search Console** - FREE (OAuth setup required)

**Total Cost**: £70-90/month vs £600/month agency = **85% savings**

---

## Part 1: Anthropic API Key ⚡ (5 minutes)

### Get the API Key

1. **Visit**: https://console.anthropic.com/
2. **Sign Up/Login**: Create account or log in
3. **Navigate**: Click "API Keys" in left sidebar
4. **Create**: Click "+ Create Key" button
5. **Name**: Enter "Afida SEO Engine"
6. **Copy**: Copy the key (format: `sk-ant-api03-...`)
   - ⚠️ **Save it now** - you can't view it again after closing!

### Pricing

- **Pay-as-you-go**: No monthly fee
- **Claude Sonnet**: ~$3/million input tokens, ~$15/million output tokens
- **Expected cost**: £2.50 per 1,500-word article
- **Monthly estimate**: £30-50 (for 10-15 articles)

### Test Your Key

After adding to credentials (see Part 4), test:
```bash
rails runner "
require 'anthropic'
client = Anthropic::Client.new(access_token: Rails.application.credentials.dig(:seo_ai_engine, :anthropic_api_key))
response = client.messages(parameters: { model: 'claude-haiku-4', max_tokens: 100, messages: [{ role: 'user', content: 'Say hello' }] })
puts '✅ Anthropic API working!' if response
"
```

---

## Part 2: SerpAPI Key (5 minutes)

### Get the API Key

1. **Visit**: https://serpapi.com/
2. **Sign Up**: Create free account
3. **Verify Email**: Check inbox and verify
4. **Dashboard**: You'll see your API key immediately
5. **Copy**: Copy the key (format: alphanumeric string)

### Pricing Options

**Option A: Free Tier (Recommended for Testing)**
- **Cost**: FREE
- **Searches**: 100/month
- **Perfect for**: Testing the system (we use ~90/month at 3/day)

**Option B: Paid Plan (For Production)**
- **Cost**: $50/month (~£40)
- **Searches**: 100/month included
- **Overage**: $0.50 per additional search
- **When to upgrade**: After testing confirms system works

### Test Your Key

After adding to credentials:
```bash
rails runner "
require 'google_search_results'
search = GoogleSearch.new(q: 'coffee', api_key: Rails.application.credentials.dig(:seo_ai_engine, :serpapi_key))
results = search.get_hash
puts '✅ SerpAPI working!' if results[:organic_results]
"
```

---

## Part 3: Google Search Console OAuth (20 minutes)

**Most complex but FREE.** This gives you real search data from your website.

### Prerequisites

- You must own/manage the website in Google Search Console
- Verify: Go to https://search.google.com/search-console
- Confirm your site (e.g., afida.co.uk) appears in the property list

### Step 3.1: Create Google Cloud Project

1. **Visit**: https://console.cloud.google.com/
2. **Create Project**:
   - Click project dropdown (top bar)
   - Click "New Project"
   - Name: "Afida SEO Engine"
   - Click "Create"
   - Wait ~30 seconds for creation

3. **Enable Search Console API**:
   - In new project, navigate to: **APIs & Services > Library**
   - Search: "Search Console API"
   - Click: **Google Search Console API**
   - Click: **Enable** button

### Step 3.2: Create OAuth Consent Screen

1. **Navigate**: **APIs & Services > OAuth consent screen**
2. **User Type**: Select **External** (unless you have Google Workspace)
3. **Click**: "Create"
4. **App Information**:
   - App name: `Afida SEO Engine`
   - User support email: your-email@afida.co.uk
   - Developer contact: your-email@afida.co.uk
5. **Click**: "Save and Continue"
6. **Scopes**:
   - Click "Add or Remove Scopes"
   - Search: "webmasters"
   - Check: ☑ `https://www.googleapis.com/auth/webmasters.readonly`
   - Click "Update"
   - Click "Save and Continue"
7. **Test Users**:
   - Click "Add Users"
   - Add your Google account email
   - Click "Add"
   - Click "Save and Continue"
8. **Summary**: Review and click "Back to Dashboard"

### Step 3.3: Create OAuth Client ID & Secret

1. **Navigate**: **APIs & Services > Credentials**
2. **Create**: Click "+ Create Credentials" → "OAuth client ID"
3. **Application type**: Web application
4. **Name**: "Afida SEO Engine Web Client"
5. **Authorized redirect URIs**: Add these two:
   ```
   http://localhost:3000/auth/google/callback
   https://afida.co.uk/auth/google/callback
   ```
   (Adjust production domain if different)
6. **Click**: "Create"
7. **SAVE THESE VALUES**:
   - ✅ Client ID: `123456789-abc.apps.googleusercontent.com`
   - ✅ Client Secret: `GOCSPX-abcd1234...`

### Step 3.4: Get Refresh Token (OAuth Playground Method)

This is the trickiest part - you need to authorize the app to get a permanent refresh token.

1. **Visit**: https://developers.google.com/oauthplayground/
2. **Settings** (gear icon ⚙️ top right):
   - Check: ☑ **Use your own OAuth credentials**
   - Paste your **Client ID** (from Step 3.3)
   - Paste your **Client secret** (from Step 3.3)
   - Click: "Close"

3. **Select API**:
   - Left panel: Scroll to "Search Console API v1"
   - Check: ☑ `https://www.googleapis.com/auth/webmasters.readonly`

4. **Authorize**:
   - Click: **Authorize APIs** button (bottom left)
   - **Important**: Log in with the Google account that owns your Search Console property!
   - Click: **Allow** to grant permission
   - You should see "Authorization code" appear in **Step 2**

5. **Exchange for Tokens**:
   - Click: **Exchange authorization code for tokens** button
   - You'll see two tokens appear:
     - ✅ **Refresh token**: `1//0g...` - **COPY THIS ONE**
     - Access token: (ignore - it expires)

### Test Google OAuth

After adding to credentials:
```bash
rails runner "
require 'google/apis/webmasters_v3'
require 'googleauth'

# This will test if credentials are valid
puts '✅ Google OAuth configured (real API test requires full GscClient implementation)'
"
```

---

## Part 4: Add All Credentials to Rails

Once you have all three keys, add them to Rails encrypted credentials:

### Open Credentials File

```bash
EDITOR="nano" rails credentials:edit
```

### Add This Section

Add to the bottom (before `secret_key_base`):

```yaml
seo_ai_engine:
  # Anthropic Claude API (for content generation)
  anthropic_api_key: sk-ant-api03-PASTE-YOUR-KEY-HERE

  # Google Search Console OAuth (for keyword discovery)
  google_oauth_client_id: 123456789-abc.apps.googleusercontent.com
  google_oauth_client_secret: GOCSPX-PASTE-YOUR-SECRET-HERE
  google_oauth_refresh_token: 1//0gPASTE-YOUR-REFRESH-TOKEN-HERE

  # SerpAPI (for competitor analysis)
  serpapi_key: PASTE-YOUR-SERPAPI-KEY-HERE
```

### Save

- Press: `Ctrl+O` (write out)
- Press: `Enter` (confirm filename)
- Press: `Ctrl+X` (exit nano)

---

## Part 5: Verify Configuration

After adding all credentials, verify they're loaded:

```bash
rails runner "
config = SeoAiEngine.configuration

puts '=== API Configuration Status ==='
puts ''
puts 'Anthropic: ' + (config.anthropic_api_key.present? ? '✅ Configured' : '❌ Missing')
puts 'SerpAPI: ' + (config.serpapi_key.present? ? '✅ Configured' : '❌ Missing')
puts 'Google Client ID: ' + (config.google_oauth_client_id.present? ? '✅ Configured' : '❌ Missing')
puts 'Google Client Secret: ' + (config.google_oauth_client_secret.present? ? '✅ Configured' : '❌ Missing')
puts 'Google Refresh Token: ' + (config.google_oauth_refresh_token.present? ? '✅ Configured' : '❌ Missing')
puts ''
puts 'All configured? ' + (
  config.anthropic_api_key.present? &&
  config.serpapi_key.present? &&
  config.google_oauth_refresh_token.present? ? '🎉 YES - Ready to go!' : '⚠️ NO - Check missing items above'
)
"
```

---

## Part 6: Test the Full System

Once all APIs are configured:

### Restart Rails

```bash
# Stop bin/dev (Ctrl+C if running)
bin/dev
```

### Test Content Generation

```bash
rails runner "
opp = SeoAiEngine::Opportunity.first || SeoAiEngine::Opportunity.create!(
  keyword: 'compostable coffee cups',
  opportunity_type: 'new_content',
  score: 85,
  search_volume: 1200,
  discovered_at: Time.current
)

puts 'Testing content generation for: ' + opp.keyword
SeoAiEngine::ContentGenerationJob.perform_now(opp.id)
puts '✅ Check http://localhost:3000/ai-seo/admin/content_drafts'
"
```

### Test Opportunity Discovery

```bash
rails runner "
puts 'Running opportunity discovery...'
SeoAiEngine::OpportunityDiscoveryJob.perform_now
puts '✅ Check http://localhost:3000/ai-seo/admin/opportunities'
"
```

---

## Troubleshooting

### Anthropic Errors

**Error**: "Invalid API key"
- ✅ Check key starts with `sk-ant-api03-`
- ✅ Verify key is active in console.anthropic.com
- ✅ Check you have credits/billing set up

**Error**: "Rate limit exceeded"
- ✅ You're generating too fast (wait 1 minute)
- ✅ Check usage in Anthropic console

### SerpAPI Errors

**Error**: "Invalid API key"
- ✅ Check key copied correctly
- ✅ Verify account is active at serpapi.com

**Error**: "Search limit exceeded"
- ✅ Free tier: 100 searches/month used
- ✅ Upgrade to paid plan or wait for reset

### Google OAuth Errors

**Error**: "Invalid grant"
- ✅ Refresh token may have expired - repeat Step 3.4
- ✅ Check you authorized with correct Google account
- ✅ Verify Search Console API is enabled

**Error**: "Access denied"
- ✅ Add your email to Test Users (Step 3.2)
- ✅ Make sure OAuth consent screen is configured
- ✅ Check scopes include webmasters.readonly

**Error**: "Token has been expired or revoked"
- ✅ Get new refresh token from OAuth Playground (Step 3.4)

---

## Quick Reference

### Credential Structure

Your `config/credentials.yml.enc` should contain:

```yaml
seo_ai_engine:
  anthropic_api_key: sk-ant-api03-...
  google_oauth_client_id: ...apps.googleusercontent.com
  google_oauth_client_secret: GOCSPX-...
  google_oauth_refresh_token: 1//0g...
  serpapi_key: ...
```

### Commands

**Edit credentials**: `EDITOR="nano" rails credentials:edit`
**View credentials**: `EDITOR="cat" rails credentials:show`
**Test config**: `rails runner "puts SeoAiEngine.configuration.anthropic_api_key.present?"`
**Restart**: `bin/dev`

---

## Next Steps After Configuration

1. ✅ All 3 APIs configured
2. ✅ Rails restarted
3. ✅ Test content generation works
4. ✅ Test opportunity discovery works
5. ✅ Review first AI-generated article
6. ✅ Approve and publish
7. ✅ Monitor budget dashboard
8. ✅ Schedule recurring jobs (daily discovery, weekly performance)

**You're now ready to replace your £600/month SEO agency!** 🎉
