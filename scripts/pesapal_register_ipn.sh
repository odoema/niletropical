#!/usr/bin/env bash
# One-time: register the IPN URL with Pesapal and print the ipn_id to store as
# the PESAPAL_IPN_ID Supabase secret. Run once per environment (sandbox, live).
#
#   export PESAPAL_ENVIRONMENT=sandbox        # or production
#   export PESAPAL_CONSUMER_KEY=...           # from your shell, never committed
#   export PESAPAL_CONSUMER_SECRET=...
#   export PESAPAL_IPN_URL=https://<project-ref>.supabase.co/functions/v1/pesapal-ipn
#   ./scripts/pesapal_register_ipn.sh
set -euo pipefail
: "${PESAPAL_ENVIRONMENT:?set to sandbox or production}"
: "${PESAPAL_CONSUMER_KEY:?}" "${PESAPAL_CONSUMER_SECRET:?}" "${PESAPAL_IPN_URL:?}"

case "$PESAPAL_ENVIRONMENT" in
  sandbox)    BASE="https://cybqa.pesapal.com/pesapalv3" ;;
  production) BASE="https://pay.pesapal.com/v3" ;;
  *) echo "PESAPAL_ENVIRONMENT must be sandbox or production" >&2; exit 1 ;;
esac

TOKEN=$(curl -sS -X POST "$BASE/api/Auth/RequestToken" \
  -H "Accept: application/json" -H "Content-Type: application/json" \
  -d "{\"consumer_key\":\"$PESAPAL_CONSUMER_KEY\",\"consumer_secret\":\"$PESAPAL_CONSUMER_SECRET\"}" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"])')

curl -sS -X POST "$BASE/api/URLSetup/RegisterIPN" \
  -H "Accept: application/json" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"url\":\"$PESAPAL_IPN_URL\",\"ipn_notification_type\":\"GET\"}" \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); print("PESAPAL_IPN_ID=" + d["ipn_id"])'
