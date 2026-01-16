# Data Model: Structured Events Infrastructure

**Feature**: 018-structured-events
**Date**: 2026-01-16

## Overview

This feature does not introduce new database entities. Events are emitted in-memory and logged to external services (Logtail). This document describes the logical data structures used.

## Logical Entities

### Event (in-memory)

An immutable record of something that happened, emitted via `Rails.event.notify`.

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | Event name in `domain.action` format |
| `payload` | Hash | Event-specific data (order_id, email, etc.) |
| `context` | Hash | Request-scoped metadata (request_id, user_id, session_id) |
| `tags` | Hash | Domain context tags (optional) |
| `timestamp` | Integer | Nanosecond Unix timestamp |
| `source_location` | Hash | `{ filepath, lineno, label }` of emit call |

**Lifecycle**: Created on emit → passed to subscribers → logged to external service → garbage collected

### Subscriber (runtime object)

A class that receives events and routes them to a destination.

| Field | Type | Description |
|-------|------|-------------|
| (class instance) | Object | Must respond to `#emit(event)` |

**Registered in**: `config/initializers/events.rb`

### Context (fiber-scoped)

Request-level metadata set once and attached to all events within that request.

| Field | Type | Description |
|-------|------|-------------|
| `request_id` | String | Rails request UUID |
| `user_id` | Integer | Current user ID (nil for guests) |
| `session_id` | Integer | Current session ID (nil for unauthenticated) |

**Set in**: `EventContext` concern via `before_action`

## No Database Migrations

This feature requires no database changes. All event data flows to Logtail via the Rails logger.

## External Data Storage

Events are stored in Logtail (Better Stack) with the following queryable fields:

| Logtail Field | Source | Example Query |
|---------------|--------|---------------|
| `event` | `event[:name]` | `event:order.placed` |
| `payload.*` | `event[:payload]` | `payload.email:customer@example.com` |
| `context.*` | `event[:context]` | `context.request_id:abc-123` |
| `timestamp` | `event[:timestamp]` | Date range filters |

**Retention**: Per Logtail account settings (free tier: 3 days)
