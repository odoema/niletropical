# Nile MTN gateway — sandbox amount integrity fix

## Purpose

The Oracle gateway must preserve the provider amount calculated by the Supabase
payment-initiate function.

For sandbox:

- Currency is EUR.
- The payer may be replaced with the documented sandbox test MSISDN.
- The amount MUST NOT be replaced with a fixed test value.
- payment-status validates the final MTN amount against immutable
  `payment_transactions.raw_response.request.amount`.

MTN documents RequestToPay as asynchronous: POST returns 202, the transaction
later reaches SUCCESSFUL/FAILED, and GET may be used to validate final status.
See the official MTN MoMo RequestToPay documentation.

## Deploy safely on Oracle

From the Oracle gateway host:

```bash
cd /opt/nile-mtn-gateway

sudo cp app.py app.py.backup-$(date -u +%Y%m%d%H%M%S)

sudo cp app.py /opt/nile-mtn-gateway/app.py.before-repo-fix 2>/dev/null || true
```

Copy the repository version of
`gateway/nile-mtn-gateway/app.py` over the live `/opt/nile-mtn-gateway/app.py`.
Do not paste or expose any environment secrets.

Then verify the critical behavior:

```bash
grep -nE 'MTN_SANDBOX_TEST_AMOUNT|request_amount|MTN_SANDBOX_TEST_MSISDN' /opt/nile-mtn-gateway/app.py
```

Expected:

- `MTN_SANDBOX_TEST_AMOUNT` does NOT occur.
- `request_amount = request.amount` occurs in the sandbox branch.
- `request_payer = MTN_SANDBOX_TEST_MSISDN` remains.

Restart only after the source check:

```bash
sudo systemctl restart nile-mtn-gateway
sudo systemctl status nile-mtn-gateway --no-pager
curl -sS http://127.0.0.1:8000/health
```

## Full-cycle controlled test

Do NOT reuse an old payment reference. MTN requires a unique X-Reference-Id
for each RequestToPay request.

Start one new checkout using the sandbox MTN success identity.

For a merchant order total of UGX 10,965 and the configured sandbox rate of
UGX 4,000/EUR, the provider request should be:

```
merchant amount: 10,965 UGX
provider amount: 2.74 EUR
provider payer: 46733123499
```

Then verify the sequence:

1. `create_order` creates `payment_pending`.
2. `payment-initiate` records the immutable provider request as 2.74 EUR.
3. Oracle POST sends 2.74 EUR to MTN.
4. MTN accepts with 202.
5. Oracle GET eventually returns `SUCCESSFUL` with 2.74 EUR.
6. `payment-status` returns HTTP 200 with `reconciled: true`.
7. `payment_transactions.status = successful`.
8. `orders.payment_status = paid`.
9. `orders.status = payment_confirmed`.
10. Flutter leaves the payment-pending screen and shows the order confirmation.

For the controlled transaction, record the order number and provider reference
as evidence. Never record gateway secrets, API keys, or private keys.

## Regression protection

A successful MTN status with a mismatched amount MUST continue to return
`PAYMENT_AMOUNT_MISMATCH`. Do not weaken that check to make the sandbox pass.
