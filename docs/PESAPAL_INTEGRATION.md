# Pesapal card checkout (API 3.0)

Card / international payments use Pesapal's hosted checkout. MTN Mobile Money,
cash on delivery, order creation and delivery tracking are unchanged.

## Flow
1. Flutter `PaymentPage` calls `payment-initiate` with `method: card`.
2. The function creates a `payment_transactions` row (`provider=pesapal`,
   `method=card`), submits the order to Pesapal and returns `redirect_url`.
3. The customer pays on the Pesapal page (opened in a new tab / browser).
4. Pesapal calls `pesapal-ipn`; the Flutter page also polls `payment-status`.
   Both run `settlePesapalTransaction`, which re-queries Pesapal with our own
   credentials and only settles if reference, amount and currency match.
5. Paid: `orders.payment_status = paid`, `status: payment_pending -> new_order`
   (same convention as MTN), email via `notification-dispatch`, once.

## Secrets (Supabase Edge Function secrets — never in git or the app)
| Name | Value |
|---|---|
| `PESAPAL_ENABLED` | `true` to accept card payments; anything else = off |
| `PESAPAL_ENVIRONMENT` | `sandbox` or `production` (must be explicit) |
| `PESAPAL_CONSUMER_KEY` / `PESAPAL_CONSUMER_SECRET` | from the Pesapal dashboard |
| `PESAPAL_IPN_ID` | printed by `scripts/pesapal_register_ipn.sh` |
| `PESAPAL_CALLBACK_URL` | optional; defaults to `https://niletropicaluganda.com/app/` |

## Sandbox rollout
```bash
supabase secrets set PESAPAL_ENVIRONMENT=sandbox PESAPAL_CONSUMER_KEY=... PESAPAL_CONSUMER_SECRET=...
supabase functions deploy pesapal-ipn --no-verify-jwt   # Pesapal sends no JWT
supabase functions deploy payment-initiate payment-status
PESAPAL_IPN_URL=https://<project-ref>.supabase.co/functions/v1/pesapal-ipn \
  ./scripts/pesapal_register_ipn.sh                      # prints PESAPAL_IPN_ID=...
supabase secrets set PESAPAL_IPN_ID=... PESAPAL_ENABLED=true
```
Then build the app with `--dart-define=PESAPAL_CARD_ENABLED=true` and place a
sandbox order. Live launch: repeat with production credentials and a new IPN id.

## Verify before going live
- Sandbox order pays, order becomes `paid`/`new_order`, one confirmation email.
- Failed / cancelled payment leaves the order retryable.
- Replaying the IPN URL does not double-notify.
- `payment_transactions` shows `provider=pesapal`, `status=successful`.

## Known limits
- A Pesapal reversal is recorded (`status=refunded`) but does not change the
  order automatically; finance reviews it.
- The Flutter page opens the payment page in a new tab; if the customer closes
  the app tab, the IPN still settles the order.
