# Supabase diagnostics — 2026-09-30 15:57 UTC

Project `ououfhsswyqutcczdtnb`. Aggregate only; no customer data.

## Orders
Total orders: **35**

**By order status**

| value | count |
|---|---|
| new_order | 12 |
| payment_pending | 11 |
| cancelled | 2 |
| delivered | 2 |
| returned | 1 |
| payment_confirmed | 1 |
| processing | 1 |
| ready_for_dispatch | 1 |
| dispatched | 1 |
| out_for_delivery | 1 |
| customer_unavailable | 1 |
| delivery_failed | 1 |

**By payment status**

| value | count |
|---|---|
| paid | 17 |
| pending | 13 |
| failed | 2 |
| unpaid | 2 |
| refunded | 1 |

**Older than 24h and not paid (order status / payment status)**

| value | count |
|---|---|
| payment_pending / pending | 11 |
| cancelled / failed | 2 |
| new_order / unpaid | 2 |
| new_order / pending | 2 |

Orders in the last 7 days: **19**

## Payments
Could not read payments (HTTP 404).
## App errors — last 7 days
Total: **55**

**By severity**

| value | count |
|---|---|
| error | 39 |
| fatal | 16 |

**Top 15 (source · code · route · action)**

| value | count |
|---|---|
| flutter_framework · - · - · framework_error | 38 |
| flutter_async · - · - · uncaught_async_error | 13 |
| flutter_async · - · (unmatched) · uncaught_async_error | 3 |
| flutter_framework · - · (unmatched) · framework_error | 1 |

## Recorded deployment failures
Records: **14**; most recent: 2026-09-28T16:27:23.135867+00:00

## Edge Functions (live)
| function | version | status | updated |
|---|---|---|---|
| analytics-dashboard | 6 | ACTIVE | 2026-09-26 13:50 |
| notification-dispatch | 8 | ACTIVE | 2026-09-26 12:29 |
| payment-initiate | 38 | ACTIVE | 2026-09-27 05:30 |
| payment-status | 29 | ACTIVE | 2026-09-27 05:30 |
| payment-webhook | 19 | ACTIVE | 2026-09-27 01:52 |
| publishing-ai-assist | 3 | ACTIVE | 2026-09-28 18:28 |
| track-order | 8 | ACTIVE | 2026-09-26 10:10 |

## Security advisor
Could not fetch (HTTP 403).

## Performance advisor
Could not fetch (HTTP 403).

