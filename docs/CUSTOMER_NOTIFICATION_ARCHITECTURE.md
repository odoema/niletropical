# Nile Tropical Customer Notifications

## Current channel

The production notification pipeline sends transactional **email** through Resend after a payment is verified as SUCCESSFUL.

Flow:

```text
MTN SUCCESSFUL
    ↓
payment-status
    ↓
orders.payment_status = paid
orders.status = new_order
    ↓
notification-dispatch
    ↓
Resend
    ↓
customer email
```

The email contains:
- customer name
- order number
- amount
- payment method
- current order status
- one-click tracking link
- copyable tracking URL

The notification is dispatched only from the server. The Flutter application never receives or stores a Resend API key.

## Resend configuration

The verified Resend sending domain currently available is `brianodoch.com`.

Production Edge Function secrets required:

```text
RESEND_API_KEY=<sending-only Resend API key>
RESEND_FROM_EMAIL=Nile Tropical <orders@brianodoch.com>
```

The API key should be a sending-only key restricted to the verified `brianodoch.com` domain.

## Duplicate protection

The notification uses a stable Resend idempotency key:

```text
payment_confirmed/<order-id>
```

Repeated payment-status polling therefore does not create duplicate confirmation emails during the normal polling window. If an email provider call temporarily fails, another successful payment-status poll can retry the notification.

## Future WhatsApp

The notification dispatcher is deliberately channel-neutral.

The event payload already carries:
- event
- order ID
- order number
- customer name
- phone
- email
- amount
- payment method
- order status
- tracking URL

The dispatcher accepts:

```json
{ "channels": ["email"] }
```

A future WhatsApp implementation can add:

```json
{ "channels": ["email", "whatsapp"] }
```

without changing the MTN payment workflow.

The WhatsApp channel is currently a safe `not_configured` placeholder. No WhatsApp provider credentials are required or stored yet.

## Important rule

Email delivery must never determine whether a payment succeeded.

The authoritative sequence remains:
1. MTN confirms payment.
2. Nile Tropical reconciles the order as paid.
3. Email notification is attempted.
4. If email fails, the order remains paid and notification delivery can be retried.

