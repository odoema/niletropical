# Checkout Safety Snapshot — 2026-09-29

## Protected production baseline

- Repository: `odoema/niletropical`
- Baseline branch: `master`
- Baseline commit: `3f841c98a2afbfe80b1208d246994211322ab0eb`
- Checkout source: `lib/features/checkout/checkout_screen.dart`
- Checkout source blob SHA: `dead8f65ae103108a64cec12d270dd3e94a8ee4c`
- Backup branch: `backup/checkout-pre-payment-redesign-2026-09-29`

## Safety rule

The payment-panel redesign is isolated from the production baseline. Existing checkout behavior for contact, delivery-zone selection, address/location search, route calculation, server-side delivery quotation, order creation/idempotency, cart clearing, COD confirmation, and non-COD payment routing must remain intact.

## Snapshot

The exact pre-redesign checkout source is preserved at:

`docs/snapshots/checkout_screen_2026-09-29.dart`

This snapshot is intentionally stored on the backup branch so it does not alter `master`.

## Recovery

If the redesign must be abandoned, the protected baseline is the `master` commit above. The backup branch also preserves the exact checkout source at the time of the redesign.

Git history is the authoritative recovery mechanism for this change.
