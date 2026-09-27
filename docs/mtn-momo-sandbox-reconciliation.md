# MTN MoMo sandbox reconciliation

Status: REPOSITORY REPAIR / NOT DEPLOYED

MTN MoMo's official sandbox contract uses EUR as the test currency. Nile Tropical's customer/order ledger remains UGX. The MTN provider-facing request therefore uses MTN_GATEWAY_CURRENCY (default EUR for the sandbox branch), while the local payment_transactions amount/currency remain the authoritative customer order amount/currency.

The provider request amount/currency is stored inside payment_transactions.raw_response.request so payment-status and payment-webhook can validate the MTN response against what was actually sent to the provider rather than incorrectly comparing a sandbox EUR response to the local UGX order ledger.

Production gate: when moving the MTN integration from sandbox to MTN Uganda production, set MTN_GATEWAY_CURRENCY=UGX and verify the production MTN account/currency contract before enabling live payments.

Official MTN sandbox test behavior also provides predefined MSISDNs for RequestToPay success/failure/pending/error cases. These must be used only for controlled sandbox tests; no real customer payment is inferred from them.