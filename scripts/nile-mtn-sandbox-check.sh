#!/usr/bin/env bash
set -euo pipefail

# Nile Tropical MTN sandbox lifecycle check.
# Safe by default: health/OpenAPI only. Set RUN_R2P=1 for a real sandbox request.
#
# Required for RUN_R2P=1:
#   MTN_GATEWAY_URL
#   MTN_GATEWAY_SHARED_SECRET
#   MTN_SANDBOX_TEST_MSISDN
#
# Optional:
#   MTN_SANDBOX_UGX_AMOUNT (default 40000)
#   MTN_SANDBOX_UGX_PER_EUR (default 4000)
#   POLL_SECONDS (default 5)
#   POLL_ATTEMPTS (default 12)
#
# The merchant ledger remains UGX. Only the MTN sandbox provider request is EUR.

GATEWAY_URL="${MTN_GATEWAY_URL:-https://132.145.240.116}"
UGX_AMOUNT="${MTN_SANDBOX_UGX_AMOUNT:-40000}"
UGX_PER_EUR="${MTN_SANDBOX_UGX_PER_EUR:-4000}"
POLL_SECONDS="${POLL_SECONDS:-5}"
POLL_ATTEMPTS="${POLL_ATTEMPTS:-12}"
RUN_R2P="${RUN_R2P:-0}"

PASS=0
FAIL=0
SKIP=0

pass() { printf 'PASS  %s\\n' "$1"; PASS=$((PASS+1)); }
fail() { printf 'FAIL  %s\\n' "$1"; FAIL=$((FAIL+1)); }
skip() { printf 'SKIP  %s\\n' "$1"; SKIP=$((SKIP+1)); }

json_field() {
  python3 - "$1" "$2" <<'PY'
import json, sys
obj=json.loads(sys.argv[1])
value=obj
for part in sys.argv[2].split('.'):
    value=value.get(part) if isinstance(value, dict) else None
print("" if value is None else value)
PY
}

echo "=== Nile Tropical MTN sandbox check ==="
echo "Gateway: $GATEWAY_URL"

if curl -fsS --max-time 15 "$GATEWAY_URL/health" >/tmp/nile_mtn_health.json 2>/dev/null; then
  cat /tmp/nile_mtn_health.json
  pass "HTTPS gateway health"
else
  fail "HTTPS gateway health"
  exit 1
fi

if curl -fsS --max-time 15 "$GATEWAY_URL/openapi.json" >/tmp/nile_mtn_openapi.json 2>/dev/null; then
  python3 - /tmp/nile_mtn_openapi.json <<'PY'
import json, sys
d=json.load(open(sys.argv[1]))
paths=d.get("paths", {})
required=[
    "/health",
    "/mtn/token",
    "/mtn/collection/request-to-pay",
    "/mtn/collection/request-to-pay/{reference_id}",
]
missing=[p for p in required if p not in paths]
if missing:
    print("Missing:", ", ".join(missing))
    raise SystemExit(1)
print("Required gateway endpoints present")
PY
  pass "Gateway OpenAPI"
else
  fail "Gateway OpenAPI"
  exit 1
fi

if [[ "$RUN_R2P" != "1" ]]; then
  skip "Sandbox RequestToPay (set RUN_R2P=1 to execute)"
  echo
  echo "Summary: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
  exit 0
fi

: "${MTN_GATEWAY_SHARED_SECRET:?MTN_GATEWAY_SHARED_SECRET is required when RUN_R2P=1}"
: "${MTN_SANDBOX_TEST_MSISDN:?MTN_SANDBOX_TEST_MSISDN is required when RUN_R2P=1}"

if ! [[ "$MTN_SANDBOX_TEST_MSISDN" =~ ^[0-9]{8,15}$ ]]; then
  fail "Sandbox test MSISDN format (must be 8-15 digits)"
  exit 1
fi

EUR_AMOUNT="$(python3 - "$UGX_AMOUNT" "$UGX_PER_EUR" <<'PY'
from decimal import Decimal, ROUND_HALF_UP
import sys
ugx=Decimal(sys.argv[1])
rate=Decimal(sys.argv[2])
if ugx <= 0 or rate <= 0:
    raise SystemExit("amount/rate must be positive")
print((ugx/rate).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))
PY
)"

REFERENCE="$(python3 - <<'PY'
import uuid
print(uuid.uuid4())
PY
)"
EXTERNAL_ID="SANDBOX-CHECK-$REFERENCE"

PAYLOAD="$(python3 - "$REFERENCE" "$EXTERNAL_ID" "$EUR_AMOUNT" "$MTN_SANDBOX_TEST_MSISDN" <<'PY'
import json, sys
print(json.dumps({
  "reference_id": sys.argv[1],
  "external_id": sys.argv[2],
  "amount": sys.argv[3],
  "currency": "EUR",
  "payer_party_id_type": "MSISDN",
  "payer_party_id": sys.argv[4],
  "payer_message": "Nile Tropical sandbox health check",
  "payee_note": "Nile Tropical sandbox health check",
  "transfer_type": "CUSTOM_PAYMENT"
}))
PY
)"

echo "Merchant test amount: UGX $UGX_AMOUNT"
echo "Sandbox provider amount: EUR $EUR_AMOUNT"
echo "Reference: $REFERENCE"

HTTP_CODE="$(curl -sS --max-time 30 -o /tmp/nile_mtn_r2p.json -w '%{http_code}' \
  -X POST "$GATEWAY_URL/mtn/collection/request-to-pay" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  -H "X-Gateway-Secret: $MTN_GATEWAY_SHARED_SECRET" \
  --data "$PAYLOAD")"

echo "RequestToPay HTTP: $HTTP_CODE"
cat /tmp/nile_mtn_r2p.json
echo

if [[ "$HTTP_CODE" == "202" ]]; then
  pass "Sandbox RequestToPay accepted (202)"
else
  fail "Sandbox RequestToPay accepted (expected 202)"
  exit 1
fi

for ((i=1; i<=POLL_ATTEMPTS; i++)); do
  STATUS_CODE="$(curl -sS --max-time 20 -o /tmp/nile_mtn_status.json -w '%{http_code}' \
    -H 'Accept: application/json' \
    -H "X-Gateway-Secret: $MTN_GATEWAY_SHARED_SECRET" \
    "$GATEWAY_URL/mtn/collection/request-to-pay/$REFERENCE")"

  STATUS="$(python3 - /tmp/nile_mtn_status.json <<'PY'
import json, sys
try:
    d=json.load(open(sys.argv[1]))
except Exception:
    print("UNKNOWN")
    raise SystemExit
for key in ("status","provider_status","financial_status"):
    v=d.get(key)
    if v:
        print(str(v).upper())
        break
else:
    print("UNKNOWN")
PY
)"

  echo "Poll $i/$POLL_ATTEMPTS: HTTP=$STATUS_CODE status=$STATUS"
  cat /tmp/nile_mtn_status.json
  echo

  case "$STATUS" in
    SUCCESSFUL|SUCCESS)
      pass "MTN sandbox final SUCCESSFUL"
      echo
      echo "Summary: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
      echo "Next application-level gate: payment_transactions -> successful; orders.payment_status -> paid; orders.status -> payment_confirmed."
      exit 0
      ;;
    FAILED|REJECTED|EXPIRED)
      fail "MTN sandbox final status: $STATUS"
      exit 1
      ;;
  esac

  sleep "$POLL_SECONDS"
done

fail "MTN sandbox did not reach a terminal SUCCESSFUL status"
echo
echo "Summary: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
exit 1
