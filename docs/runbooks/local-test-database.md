---
type: Runbook
description: Why fixture-based tests need a privileged PostgreSQL role, the two ways to grant it, and how the suite now fails when neither is in place.
status: active
timestamp: 2026-08-20
---

# Local Test Database Privileges

Running `bin/rails test` against a PostgreSQL role without the right privilege used to break the entire suite — around 3,000 errors, none of which named the real cause. This records what is actually going on and how it is now handled.

## The failure

The first symptom is a warning Rails prints and then ignores:

```
WARNING: Rails was not able to disable referential integrity.
Rails needs superuser privileges to disable referential integrity.
    cause: PG::InsufficientPrivilege: ERROR:  permission denied:
           "RI_ConstraintTrigger_c_17448" is a system trigger
```

Every fixture-based test then dies on something that looks unrelated:

```
ActiveRecord::InvalidForeignKey: insert or update on table "addresses"
violates foreign key constraint "fk_rails_48c9e0c5a2"
DETAIL:  Key (user_id)=(980190962) is not present in table "users".
```

That second error is misleading in a specific and costly way. It names `addresses`, `users`, and a fixture id, so it reads as a broken fixture — and it is not. `980190962` is `ActiveRecord::FixtureSet.identify(:one)`, and `users(:one)` exists and is perfectly valid.

## Why it happens

Rails inserts every fixture table in a single batch wrapped in `disable_referential_integrity`, and inserts those tables in **alphabetical order** — `addresses` long before `users`. That only works because foreign-key checking is supposed to be switched off for the duration.

To switch it off, Rails issues `ALTER TABLE ... DISABLE TRIGGER ALL`. PostgreSQL backs foreign keys with internal *system* triggers, and refuses to let anyone but a superuser disable those. Owning the table is not enough; owning the database is not enough.

When that `ALTER` is refused, Rails warns, proceeds anyway, and the alphabetical insert order does the rest. **Nothing is wrong with the fixtures.** The role simply cannot defer the checks.

## The fix

Either of these works. Both must be run by a superuser (typically `postgres`).

```sql
-- Broad: what Rails' own warning suggests.
ALTER ROLE your_role SUPERUSER;

-- Narrow, and preferred (PostgreSQL 15+): grants exactly one setting.
GRANT SET ON PARAMETER session_replication_role TO your_role;
```

The narrow grant is worth preferring — a development role should not need superuser over the whole cluster just to run tests. It is not quite equivalent, though: see [the second privilege](#the-second-privilege) below.

It does, however, need help: `session_replication_role` suppresses foreign-key triggers just as effectively, but **stock Rails never sets it**, so the grant alone changes nothing. `test/support/referential_integrity_check.rb` prepends `ReferentialIntegrityCheck::ViaSessionReplicationRole` to the PostgreSQL adapter to close that gap. Roles that *can* use Rails' own `ALTER TABLE` path keep using it untouched; the override only takes over when that path would fail.

## The second privilege

Clearing the first hurdle is not enough. Once fixtures are inserted, Rails runs `check_all_foreign_keys_valid!` (`ActiveRecord.verify_foreign_keys_for_fixtures`, on by default) to re-validate every constraint. It does that by writing to `pg_catalog.pg_constraint` directly:

```sql
UPDATE pg_catalog.pg_constraint SET convalidated = false WHERE conname = ...;
ALTER TABLE ... VALIDATE CONSTRAINT ...;
```

Writing a system catalog is superuser-only and **cannot be granted**. A role using the narrow grant therefore gets past the insert and fails here instead, with a message that blames the fixtures for a third time:

```
RuntimeError: Foreign key violations found in your fixture data. Ensure you
aren't referring to labels that don't exist on associations.
  PG::InsufficientPrivilege: ERROR:  permission denied for table pg_constraint
```

Only the last line is true. `test/test_helper.rb` probes for this separately and, when the role cannot do it, turns `verify_foreign_keys_for_fixtures` off with a one-line note rather than letting it fail. That does lose a real safety net — it is what catches fixtures pointing at labels that do not exist — so it is a deliberate trade: unprivileged roles run the suite without it, and CI, which runs as `postgres`, keeps it.

If you want that check locally, `ALTER ROLE ... SUPERUSER` is the only way to get it.

## Failing fast

`test/test_helper.rb` probes the connection once at boot and aborts with an actionable message when neither route is available, rather than letting the cascade run. Verified against a deliberately unprivileged role: one message, exit 1, no stack traces.

The probe deliberately targets a table that *has* a foreign key (`SELECT conrelid::regclass::text FROM pg_constraint WHERE contype = 'f' LIMIT 1`). `DISABLE TRIGGER ALL` on a table with no foreign keys has no system triggers to object to and succeeds for any owner, which would make the check pass while the suite still broke.

## CI is unaffected

`.github/workflows/ci.yml` runs PostgreSQL with `POSTGRES_USER: postgres`, which is a superuser. This has only ever been a local-development problem, which is why it survived unnoticed — and why it is easy to reintroduce on a fresh machine without CI saying a word.
