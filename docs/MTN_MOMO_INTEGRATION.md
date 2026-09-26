# MTN Mobile Money (MoMo) Production Integration

## Purpose

This document records how Nile Tropical's MTN Mobile Money payment flow was made to work in production, so the working architecture is preserved in GitHub and can be maintained without relying on undocumented setup knowledge.

The integration is intentionally **server-side**. The Flutter/web client does not hold MTN credentials, does not mark an order as paid, and does not call the MTN provider directly.

---

## 1. Production architecture

The payment path is:

```
Customer
   |
   | Checkout
   v
Flutter/Web App
   |
   | order + payment method
   v
Supabase create_order()
   |
   | status = payment_pending
   | payment_status = pending
   v
payment-initiate Edge Function
   |
   | authenticated server-to-server request
   v
Nile Tropical MTN gateway adapter
   |
   | MTN Collection / Request-to-Pay
   v
MTN Mobile Money
   |
   | customer approves prompt
   v
MTN gateway adapter
   |
   | status lookup
   v
payment-status Edge Function
   |
   | SUCCESSFUL
   +--------------------+
   |                    |
   v                    v
orders                  notification-dispatch
payment_status=paid     |
status=new_order        +--> Resend email
   |
   v
order_status_history
   |
   v
Track Order
```

The production Supabase project is the backend authority. The browser/mobile application is never trusted to declare a successful payment.

---

## 2. The key discovery that made the integration work

The stable production approach was to put the MTN-specific credentials and provider communication behind a server-side gateway adapter.

The application calls two Supabase Edge Functions:

- `payment-initiate` — starts the MTN Request-to-Pay transaction.
- `payment-status` — checks the provider transaction and reconciles the result into the order.

The client therefore needs only the normal Supabase URL/anon-key configuration. MTN credentials and the gateway shared secret remain server-side.

This separation also makes it possible to replace or upgrade the MTN provider adapter without rewriting checkout.

---

## 3. Payment initiation

Source:

`supabase/functions/payment-initiate/index.ts`

For an MTN order, the function:

1. Finds the order by `order_id` or `order_number`.
2. Confirms that the order's payment method is actually `mtn_momo`.
3. Requires the order to be in `payment_pending`.
4. Uses the checkout phone stored in `customer_phone_snapshot`.
5. Generates a new UUID `reference_id`.
6. Sends a server-side POST to the gateway's MTN Request-to-Pay endpoint:
   `/mtn/collection/request-to-pay`.
7. Sends:
   - `reference_id`
   - `external_id` = Nile Tropical order number
   - `amount`
   - `currency` = `UGX`
   - payer type = `MSISDN`
   - payer phone
   - customer/payment messages
   - `CUSTOM_PAYMENT` transfer type
8. Treats HTTP/upstream status `202` as successful initiation.
9. Returns the reference to the client and tells the customer to approve the MTN prompt.

The gateway URL and shared secret are read from server-side environment variables:

- `MTN_GATEWAY_URL`
- `NILE_MTN_GATEWAY_URL`
- `MTN_GATEWAY_SHARED_SECRET`
- `NILE_MTN_GATEWAY_SECRET`
- `GATEWAY_SHARED_SECRET`

The code supports the first two URL names and the secret aliases for backward compatibility.

**Never put the shared secret in Flutter, JavaScript, GitHub source, or browser storage.**

---

## 4. Why the order number is used as the provider external ID

The request uses:

```
external_id = order.order_number
```

This creates a useful binding between the MTN transaction and the Nile Tropical order.

During status reconciliation, `payment-status` checks the gateway response's `externalId`. If the provider returns an external ID that does not match the Nile Tropical order number, the function rejects the reconciliation with:

```
PAYMENT_ORDER_MISMATCH
```

This prevents a valid MTN transaction from being accidentally applied to the wrong order.

---

## 5. Payment verification / reconciliation

Source:

`supabase/functions/payment-status/index.ts`

The client polls `payment-status` using the initiation reference.

The function asks the gateway for:

```
GET /mtn/collection/request-to-pay/{reference}
```

It maps the provider status as follows:

| MTN/gateway status | Nile Tropical payment status |
|---|---|
| `SUCCESSFUL` | `paid` |
| `FAILED` | `failed` |
| `REJECTED` | `failed` |
| `PENDING` | `pending` |

For a successful payment, the function updates the database server-side.

If the order is still `payment_pending`, a successful payment also changes:

```
status = new_order
payment_status = paid
```

The client cannot directly perform this reconciliation.

---

## 6. The important lifecycle fix

An earlier version allowed a real paid transaction to remain at:

```
status = payment_pending
payment_status = paid
```

That was inconsistent because the money had been received while the order was still waiting for payment.

The production fix makes successful MTN reconciliation atomic at the application level:

```
payment_status: pending -> paid
status:          payment_pending -> new_order
```

The order-history trigger then records the transition.

The resulting tracking timeline can therefore show:

- **new_order — Order created**
- **new_order — Payment confirmed; order released for processing**

This exact lifecycle has been verified on the live Nile Tropical production order.

---

## 7. Preventing duplicate payment emails

Payment-status polling can run more than once. Therefore, a successful payment must not cause a confirmation email every time the client polls.

The function keeps the previous payment state and calculates:

```
paymentJustBecamePaid =
  newPaymentStatus == "paid"
  AND previousPaymentStatus != "paid"
```

Only when that expression is true does it call:

```
notification-dispatch
```

with:

```
event = payment_confirmed
channels = ["email"]
```

This means repeated polling of an already-paid transaction does not intentionally generate another payment-confirmation dispatch.

---

## 8. Email notification

Source:

`supabase/functions/notification-dispatch/index.ts`

The notification function is deliberately channel-neutral.

Current channel:

- **Email → Resend**

Reserved future channel:

- **WhatsApp → WhatsApp Business API/provider**

The payment confirmation email contains:

- customer name
- order number
- amount
- payment method
- current order status
- a **Track My Order** button
- the tracking URL as fallback text

The Resend request also uses:

```
Idempotency-Key = event/orderId
```

This provides an additional protection against duplicate email sends for the same event and order.

Required server-side email secret:

- `RESEND_API_KEY`

Optional/configurable sender:

- `RESEND_FROM_EMAIL`

---

## 9. Tracking

Source:

`supabase/functions/track-order/index.ts`

The customer supplies:

- order number
- phone used at checkout

The tracking function verifies the phone against the stored checkout phone using the final nine digits, which accommodates normal Uganda phone formatting differences.

It then returns:

- order number
- order status
- payment status
- total
- creation time
- order status history
- latest shipment information

The tracking page is therefore reading the same production order state that was reconciled by the payment flow.

A live production verification showed:

```
Order:          NT-20260926-035043604-DC36A3D8
Payment:        paid
Status:         new_order
Amount:         UGX 21,000
Timeline:       Order created
                Payment confirmed; order released for processing
```

---

## 10. Secrets and configuration

Do not commit secret values.

The production Edge Functions require the appropriate Supabase and provider secrets to be configured in the Supabase Edge Function environment.

Relevant names include:

```
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY

MTN_GATEWAY_URL
NILE_MTN_GATEWAY_URL
MTN_GATEWAY_SHARED_SECRET
NILE_MTN_GATEWAY_SECRET
GATEWAY_SHARED_SECRET

RESEND_API_KEY
RESEND_FROM_EMAIL
NILE_TROPICAL_TRACKING_BASE_URL
```

The GitHub repository contains the function source, but not the secret values.

---

## 11. Deployment

GitHub Actions deploys the production Edge Functions when changes under `supabase/functions/**` are pushed to `master`.

The current deployment workflow is:

`/.github/workflows/deploy-supabase-functions.yml`

It deploys:

- `track-order`
- `notification-dispatch`
- `payment-initiate`
- `payment-status`

Database migrations are currently applied separately in the production Supabase SQL Editor. The migration/deployment workflow should eventually be automated, but it should be done carefully because production schema changes are stateful.

---

## 12. What must be preserved

Do not simplify the MTN implementation by moving provider credentials into the client.

Do not allow the client to:

- set `payment_status = paid`
- set an order to `new_order` because the user says payment succeeded
- bypass the provider status check
- supply an arbitrary amount to the provider
- supply an arbitrary external order ID for reconciliation

The authoritative chain is:

```
database order
   -> server-side initiation
   -> MTN Request-to-Pay
   -> server-side status verification
   -> externalId/order-number validation
   -> database payment reconciliation
   -> order history
   -> customer notification
   -> tracking
```

---

## 13. Current status

The integration has passed the following production checks:

- MTN Request-to-Pay initiation
- successful MTN payment reconciliation
- payment status changed to `paid`
- order released from `payment_pending` to `new_order`
- order-status history recorded the payment confirmation
- production tracking displayed the paid order and timeline
- legacy SMS queue records were isolated/failed rather than remaining active
- payment confirmation email dispatch is protected against repeated polling

The remaining step is the final controlled end-to-end live payment smoke test, including verification of the customer email and notification behavior.

---

## 14. Maintenance rule

When changing the MTN payment flow, update this document in the same change/commit.

The source of truth for the implementation is:

- `supabase/functions/payment-initiate/index.ts`
- `supabase/functions/payment-status/index.ts`
- `supabase/functions/notification-dispatch/index.ts`
- `supabase/functions/track-order/index.ts`
- `.github/workflows/deploy-supabase-functions.yml`

Never document or commit actual provider secrets.
