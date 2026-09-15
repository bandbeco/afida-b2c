---
type: Runbook
description: Deploy, operate and recover the isolated FSA lead monitor and its manual opening review workflow.
status: active
timestamp: 2026-09-15
---

# Lead monitor

Open **Lead monitor** from the admin navigation, or visit `/admin/lead-monitor/leads`. An authenticated admin is required for review, CSV export and contact activity.

## Deployment

1. Run `bin/rails db:migrate` to create the five `lead_monitor_*` tables. No existing domain tables change.
2. Set `LEAD_MONITOR_DIGEST_TO` to the internal review mailbox in the deployment environment (for Kamal, add it under `env.clear` in `config/deploy.yml`). The existing Action Mailer host and delivery configuration are reused. No FSA API key is needed.
3. Restart the Solid Queue supervisor with the updated recurring configuration. Discovery runs Mondays at 07:00 Europe/London, including daylight-saving changes. Digest recovery runs hourly. Both use the dedicated `lead_monitor` queue, consumed by the existing wildcard worker configuration. It can be assigned a separate worker later without changing the module.
4. Optionally run `LeadMonitor::DiscoverJob.perform_later` in the Rails console for the initial baseline. This fetches the current target pool and creates sightings, without creating prospects. A seed digest confirms the run. Later identities enter the review queue as possible openings.

Without a digest recipient, discovery still works and pending runs remain visible in the UI; delivery resumes once the recipient is configured. This feature does not send prospect messages. Confirm the starter-kit offer is ready before starting manual outreach.

## Review workflow

Verify that evidence names this venue and address. Record a business announcement or local-report URL, or dated notes from direct confirmation. Select the planned opening date for “Opening soon”, or the actual opening date for “Confirmed recent opening”. The logged-in admin and review timestamp are recorded when evidence changes.

Leave uncertain or conflicting dates as “Possible new opening”. Use “Existing business / ownership change” for old locations and takeovers without a new location. Incorporation, first reviews and awaiting-inspection status may guide research but do not qualify an opening.

Add contact details, personalise the kit draft, send it manually, and record the message and channel. Follow-ups are due 1, 2 and 7 days after initial contact; overdue follow-ups are spaced at least a day apart. Each recorded outbound contact rechecks eligibility. A reply or suppression stops the sequence. Expired qualifications show “Recheck opening date”; confirm an actual opening rather than advancing an elapsed planned date automatically.

CSV exports contain evidence, classification and eligibility as of export time, plus contact status. Eligibility in an old export is not permission for a later contact; recheck in the monitor. Keep exports out of version control.

## Failure recovery and limits

The queue shows the five most recent runs and their digest state. A digest that a worker claimed but never sent is retried by the hourly sweep once the claim is ten minutes old. A failed fetch or import creates a failed run without advancing sightings or the baseline. The failed run stores the exception class and message, the same failure is reported to Sentry, and application logs carry it under `[LeadMonitor]`. Correct the source/API problem and rerun discovery. Do not delete source or sighting records to retry: that would discard the baseline.

The fetcher polls restaurant/café/canteen, pub/bar/nightclub, takeaway/sandwich shop and mobile-caterer types in the FSA AwaitingInspection pool. Missing pages or malformed metadata fail the whole snapshot. HTTP requests time out after 30 seconds; rate limits have two retries with delays capped at 60 seconds. A count change or duplicate identity during pagination refetches that business type once; a second mismatch fails the run, which can be retried later. The API offers no immutable snapshot token, so count validation cannot prove that a live dataset was unchanged.

Identities seen before the seed, businesses never present in this pool, and businesses entering and leaving between weekly polls will not become leads. New registration identities and ownership changes can produce candidates; manual evidence determines whether they qualify. A failed week can recover on the next successful snapshot if the identities are still in the pool.

`LeadMonitor::DeliverDigestsJob.perform_later` retries pending digests independently. Mail failures leave runs pending for the hourly sweep. Delivery can duplicate a message if the process stops after email acceptance but before recording success; the subject includes the stable run ID. Missing or failed discovery jobs cannot create a run, so continue monitoring Solid Queue failures alongside the run list.

To stop discovery, remove its recurring entry and restart the scheduler. Keep the tables and baseline intact. Existing queue/review data does not affect storefront behavior.

## Validation

Run the module tests with:

    bin/rails test test/models/lead_monitor test/services/lead_monitor test/jobs/lead_monitor test/controllers/lead_monitor

The browser workflow lives in `test/system/lead_monitor_test.rb`. It requires Chrome and its runtime libraries; set `CHROME_BIN` if Chrome is outside the normal executable path. HTTP tests use WebMock and never poll live businesses. See [the architecture decision](/adr/0002-isolated-lead-monitor.md) for isolation boundaries and delivery guarantees.
