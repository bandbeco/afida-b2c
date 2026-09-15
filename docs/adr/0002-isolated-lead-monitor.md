---
type: ADR
description: Isolate register discovery, opening qualification and manual outreach in the LeadMonitor namespace with no storefront model dependencies.
status: active
timestamp: 2026-09-15
---

# Isolated lead monitor

The monitor discovers candidates for the new-opening kit. A business first seen in an FSA awaiting-inspection snapshot is a research candidate, not a confirmed new opening. A new trading location from an established operator can qualify; incorporation or a change of owner alone cannot.

All domain records, services, jobs and mailers live under `LeadMonitor`. Its five tables have the `lead_monitor_` prefix and foreign keys only within the module. The abstract record inherits directly from Active Record; jobs and mailers inherit Rails framework classes. There are no associations, callbacks or writes to customers, orders, products, carts or marketing integrations.

The controller shares the host's `Authentication` concern and admin check, but inherits directly from `ActionController::Base` and uses a dedicated layout. Reviewer identities are stored as strings supplied by this adapter, without a foreign key to users. The host integration consists of routes, an admin navigation link, recurring schedules, existing CSS and shared Rails infrastructure. This keeps extraction possible without introducing an engine or a second deployment now.

## Discovery boundary

The injected fetcher returns normalized attributes for a complete source snapshot or raises. V1 polls four FSA business types in the AwaitingInspection pool; it does not scan the full register. Missing identity, missing metadata, failed pages, count changes or duplicate page identities reject the snapshot. Rate-limit retries and pagination are bounded. Only discovered leads retain the source payload.

A unique source record tracks seeding independently of sightings, including successful empty seeds. A source row lock serializes fetch and import. Sightings, new unqualified leads, the seed marker and a run record commit together. Persistence failures roll back the complete import and create a failed run. Existing identities are never recreated or overwritten.

Each run is also a durable pending digest. An hourly sweep recovers notifications if a worker stops before enqueueing the immediate digest. A row lock prevents normal concurrent delivery; a successful send records `notified_at`. Delivery is at least once: a crash after email acceptance but before the database commit can duplicate a digest. The run ID appears in the subject so duplicates are recognizable.

## Qualification and contact boundary

Upcoming and recent classifications require a verified venue/address, an opening date, accepted evidence and a dated human review. Recent means the inclusive interval from today minus 60 days through today. Upcoming means strictly after today. Evidence is a business announcement, local reporting or direct confirmation with notes. A planned date that has elapsed never becomes an actual opening automatically.

Qualification is stored separately from contact activity. Each outbound activity is checked under a lead row lock against current evidence, dates, contact details, reply/suppression state and follow-up timing. The module provides drafts and logs manual contacts; it does not send prospect messages. Initial contact can be followed up on days 1, 2 and 7. Replies and suppression stop the sequence.

Automated enrichment, automated outreach, list recycling and storefront conversion attribution are deferred until manual discovery quality is assessed. Any future integration should call an explicit adapter; it must not add callbacks or foreign keys into the storefront domain.
