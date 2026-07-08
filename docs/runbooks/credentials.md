---
type: Runbook
description: How Rails credentials are structured here; production reads the shared vault, and how to edit without poisoning resolution.
status: active
timestamp: 2026-07-08
---

# Rails Credentials

## Layout

Production reads the SHARED vault, `config/credentials.yml.enc`. There is deliberately no separate production vault.

## Editing

```
RAILS_ENV=production bin/rails credentials:edit
```

Never use `-e production`: that creates `config/credentials/production.*` files, and any stray `production.*` files poison key and content resolution for every subsequent read.

## Tests and CI

CI decrypts `config/credentials/test.yml.enc` (fake values only) via the `RAILS_TEST_KEY` secret, so `RAILS_ENV=test` returns the fake test-vault values both in CI and locally. Tests should assert against the credential value (`Rails.application.credentials...`), never against a literal or `nil`.
