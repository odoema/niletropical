# Nile Tropical Uganda — Payment Provider Readiness

**Status:** Preparation only; no provider credentials, production configuration, database changes, or payment code changes are included.  
**Prepared:** 2026-09-29  
**Repository:** odoema/niletropical  
**Production Supabase target (must be verified before deployment):** ououfhsswyqutcczdtnb

## Decision summary

Start merchant onboarding and technical confirmation with **Pesapal Uganda** as the first candidate for the custom Flutter/web checkout. Its Uganda business pages currently advertise online card payments (Visa, Mastercard and AMEX), mobile money, and payment reporting in UGX and USD. Its Uganda site identifies a local office and describes online API integration for custom-built websites.

Official references:
- https://www.pesapal.com/ug/business
- https://www.pesapal.com/ug/business/online
- https://www.pesapal.com/ug/business/online/api-plugins

This is a candidate recommendation, **not confirmation of an approved merchant account or a guarantee that every requested scheme is available**.

### Requested methods versus evidence

| Method | Current evidence / readiness |
|---|---|
| Visa | Advertised by Pesapal Uganda for online payments; confirm on the Nile Tropical merchant profile. |
| Mastercard | Advertised by Pesapal Uganda for online payments; confirm on the Nile Tropical merchant profile. |
| MTN Mobile Money | Advertised by Pesapal Uganda's current business pages. Nile Tropical also has an existing separate MTN gateway flow. Decide whether to keep that flow or migrate only after reconciliation and end-to-end testing. |
| Airtel Money | Advertised by Pesapal Uganda's current business pages. Current Nile Tropical payment-initiate function returns 503 PAYMENT_PROVIDER_NOT_CONFIGURED for Airtel. |
| American Express | Advertised by Pesapal for online payments; optional additional method if enabled for this merchant. |
| Maestro | Not confirmed by the reviewed official Uganda pages. Ask Pesapal in writing. |
| Visa Electron | Not confirmed as a separately accepted scheme. Ask Pesapal in writing; do not display as guaranteed. |
| PayPal | Not advertised as a Pesapal Uganda checkout method in the reviewed pages. Treat as unsupported until a provider confirms a supported integration. |
| Skrill | Not advertised as a Pesapal Uganda checkout method in the reviewed pages. Treat as unsupported until a provider confirms a supported integration. |
| Cash on Delivery | Existing Nile Tropical checkout option; must remain independent and must not call a gateway. |

**Important:** No single candidate has yet been verified to support every requested method for this Ugandan merchant. Do not promise PayPal, Skrill, Maestro, or Visa Electron until the provider confirms eligibility, availability, settlement, and integration details. If these are mandatory, request a second-provider/hosted-wallet option and compare merchant eligibility before implementation.

## Existing code contract (preserve)

Current canonical checkout payment methods:
- mtn_momo
- airtel_money
- card
- cash_on_delivery

The current Supabase Edge Function payment-initiate supports an MTN gateway flow. It explicitly returns 503 PAYMENT_PROVIDER_NOT_CONFIGURED for airtel_money and card. The client payment page polls payment-status for reconciliation.

Preserve:
- order creation and order-number contract;
- server-authoritative order amount, currency, stock, and delivery quote;
- existing payment method values unless a deliberate, backward-compatible migration is reviewed;
- payment transaction audit trail and idempotency protections;
- server-side payment-status reconciliation;
- order status/payment status transition rules;
- COD checkout and order confirmation behavior;
- customer notification behavior after confirmed payment.

Never mark an order paid based solely on a browser redirect or client-supplied status.

## Proposed staged integration

### Stage 1 — Merchant onboarding (no code or production changes)

1. Apply through the official Pesapal Uganda business page: https://www.pesapal.com/ug/business
2. Tell the provider the merchant is a Uganda-based, custom-built Flutter/web ecommerce store selling physical consumer products.
3. Request a production merchant account and sandbox/test credentials for custom API integration.
4. Obtain written answers to the scheme checklist above, including PayPal, Skrill, Maestro, and Visa Electron availability for this merchant in Uganda.
5. Confirm supported currencies (UGX required for checkout), transaction limits, fees, settlement bank requirements, refunds/chargebacks, payment expiry, and merchant verification/KYC documents.
6. Request current API documentation for authentication, order submission, callback/redirect, IPN/webhook, transaction-status verification, idempotency, refunds, and sandbox scenarios.

### Stage 2 — Implement behind a feature branch

Only after the account/API contract is confirmed:
1. Add a server-side provider adapter in Supabase Edge Functions; secrets must never be shipped to Flutter or the browser.
2. Create a local payment transaction before contacting the provider, using a unique idempotency/reference key and authoritative order total.
3. Create a provider order and open the provider-hosted checkout URL. Do not collect or store card PAN/CVV in Nile Tropical.
4. Validate callbacks server-side and independently query the provider transaction-status API before any payment state transition.
5. Make IPN/webhook processing idempotent; bind each provider transaction to the exact local order, expected amount, currency, and merchant reference.
6. Handle pending, successful, failed, cancelled, expired, duplicate, out-of-order, and amount/currency-mismatch events.
7. Reconcile provider references and local transaction records. Never infer success from an HTTP 200 alone.
8. Keep the existing MTN direct flow until the new provider route is proven. Avoid duplicate/confusing MTN/Airtel options until routing is explicitly decided.
9. Display only payment methods actually enabled by the merchant account; logos are not evidence of acceptance.

### Stage 3 — Test and release gates

Required tests:
- valid sandbox payment success and server-side reconciliation;
- failure, customer cancellation, expiry, delayed callback, duplicate callback, and retry;
- wrong order reference, wrong amount, wrong currency, and unknown provider transaction;
- repeated requests/idempotency and webhook replay;
- payment initiation network timeout with later provider success;
- COD unaffected;
- delivery quote, stock validation, order creation, and cart-clearing behavior unchanged;
- email confirmation sent only after authoritative success, without duplicate messages;
- mobile and desktop checkout, back-navigation, and provider-return flow;
- Flutter analysis/tests, Edge Function tests, and production-build check.

Do not deploy or enable live payment methods until all gates pass and the production Supabase project reference has been independently verified.

## Required configuration (names only; never commit secret values)

Exact variable names must be aligned to the provider's current API and existing Supabase deployment conventions during implementation. Proposed names:
- PESAPAL_ENVIRONMENT (sandbox or production)
- PESAPAL_CONSUMER_KEY
- PESAPAL_CONSUMER_SECRET
- PESAPAL_CALLBACK_URL
- PESAPAL_IPN_ID (if required by provider)
- PESAPAL_WEBHOOK_SECRET (only if provider uses a signing secret)
- NILE_TROPICAL_PUBLIC_BASE_URL

Store credentials only as Supabase Edge Function secrets. Do not put credentials in repository files, Flutter assets, client-side environment variables, logs, or this document.

## Information needed from merchant onboarding

- Registered legal business name and registration details;
- TIN and business verification/KYC documents as requested by provider;
- settlement bank account details in the registered business name, as required;
- business website and public contact/support details;
- product category, fulfilment/delivery policy, refund/returns policy, privacy policy, and terms;
- estimated monthly transaction volume and typical order value;
- named technical contact for sandbox integration;
- provider-approved list of payment methods and supported currencies.

Submit sensitive documents only through the provider's official secure onboarding channel, not GitHub or chat.

## Current release decision

**Not ready for production payment-provider deployment.** There is no merchant account yet, no provider credentials, and no verified access to the Nile Tropical production Supabase project through the connected Supabase integration. This branch is documentation-only and intentionally makes no production changes.
