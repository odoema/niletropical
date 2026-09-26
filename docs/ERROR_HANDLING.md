# Nile Tropical — Production Error Handling Standard

## Goal

Customers and staff should see short, professional recovery guidance. Technical details must go to diagnostics, not the user interface.

## Error flow

1. A failure occurs.
2. The central `ErrorReporter` class classifies and redacts it.
3. A safe production record is written to `public.app_error_logs`.
4. The UI shows a friendly message and, where possible, a retry action.
5. Staff investigate from **Admin → Error Logs**.
6. Staff mark the incident resolved and record the resolution note.

## User-facing rules

Never display:

- raw `PostgrestException` messages
- SQL/database schema names
- stack traces
- Supabase project details
- provider/API secrets
- access or refresh tokens
- payment gateway internals
- raw HTTP responses

Prefer messages such as:

- "We could not complete that request. Please try again."
- "We are having trouble connecting right now. Please check your internet connection and try again."
- "You do not have permission to perform this action."
- "Your session may have expired. Please sign in again and retry."

## Logging rules

Every important catch block should call:

`ErrorReporter.report(error, stackTrace: stack, source: ..., action: ...)`

Include only safe context such as:

- route
- action name
- record UUID
- order number when appropriate
- non-sensitive operation metadata

Do not include passwords, OTPs, tokens, card data, secrets, or unnecessary customer PII.

## Severity

- **info** — expected diagnostic event
- **warning** — recoverable anomaly
- **error** — failed user/admin operation
- **fatal** — uncaught application failure

## Rollout plan

### Phase 1 — foundation
- Global Flutter framework and uncaught async error capture.
- Structured Supabase error classification.
- Redaction.
- Error Logs admin console.
- RLS-protected diagnostics.
- Shared friendly error state.

### Phase 2 — critical journeys
Wire explicit reporting and friendly messages into:

- login/authentication
- product management
- inventory
- pricing
- orders
- checkout
- MTN Mobile Money
- COD
- tracking
- notifications/email
- media uploads
- analytics
- CMS

### Phase 3 — backend
Add the same event format to Supabase Edge Functions and scheduled workers so payment, notification, tracking and dispatch failures can appear in the same Admin console.

### Phase 4 — operations
Add:

- error grouping by fingerprint
- occurrence counts
- first/last seen
- affected route/action
- unresolved alerts
- retention policy
- optional email/WhatsApp alerts for critical failures

The Error Logs page is an operational diagnostic tool; it must never expose technical errors to customers.
