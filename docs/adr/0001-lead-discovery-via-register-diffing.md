---
type: ADR
description: New-business leads are discovered by first-seen diffing of register snapshots (Sighting vs Lead split), not by trusting register status fields.
status: active
timestamp: 2026-07-15
---

# Lead discovery via register snapshot diffing

Afida's lead monitor needs to detect newly opened UK food businesses from public registers (FSA FHRS in v1). The obvious approach, treating the register's own "awaiting inspection" status as "newly opened", is wrong: verified live, some Scottish FHIS records have carried that status since 2021. We decided that **newness is defined by first-seen diffing**: a weekly job records every observed register identity as a Sighting (source + external id, insert-only), and a Lead is created only when an identity first appears *after* that source's seed run. The seed run imports the whole standing register (~15k identities) silently.

Sightings and Leads are **two tables, not one table with a "seeded" status**, so `leads` only ever contains real prospects, admin/counts never see mechanism rows, and no payload is stored for register backfill. The fetcher is deliberately all-or-nothing (any failed page fails the whole weekly fetch) because a *partial* seed would leak thousands of old register entries as fake "new" leads over the following weeks. A crash between recording sightings and creating their leads would silently swallow those leads forever, so both writes share one transaction.

## Considered options

- **Trust the register's AwaitingInspection status** — rejected: status is not evidence of newness (stale FHIS records).
- **One `leads` table with a `seeded` status** — rejected: permanently pollutes the lead concept and every query with ~15k mechanism rows.
- **Separate app or Monday CRM plugin** — rejected: the shop app already has jobs, mailers, admin and deploy infrastructure, and leads gain value joined to shop data (conversion tracking). A Monday board *push* stays possible later via their API.
- **Companies House as a second v1 source** — deferred: its unique value (PECR-legal cold email to limited companies, earlier incorporation signal) is locked until an email-enrichment step exists, and its registered addresses are often formation agents rather than shops. The Sighting/Lead schema and per-source job structure accept it without change.

## Consequences

The first digest after deployment reports "seeded N, nothing new"; real leads start in week two. A business is missed only if it enters *and* leaves the awaiting-inspection pool between two successful weekly runs; a failed week self-heals because identities are diffed, not windowed.
