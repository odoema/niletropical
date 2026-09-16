-- 021_payment_providers.sql
--
-- FIX (2026-09-11): the prior version created a separate `payment_provider`
-- enum (mtn_direct / airtel_direct / card_direct / cash) and tried to alter
-- `payments.provider` — but the payments table (007_payments.sql) has no
-- `provider` column. Provider identity lives on `payment_transactions.provider`
-- as free-form text (correctly), so an enum is unnecessary. The
-- `payment_method` enum defined in 006_orders.sql — mtn_momo, airtel_money,
-- card, cash_on_delivery — is the authoritative set for how the customer
-- chose to pay, and the Flutter client has been aligned to those values.
--
-- This migration is a no-op documenting that. It stays in the sequence so
-- filename ordering is preserved and `supabase db push` runs cleanly.

DO $$
BEGIN
  RAISE NOTICE
    '021_payment_providers: no-op. The payment_method enum in 006_orders.sql '
    '(mtn_momo, airtel_money, card, cash_on_delivery) is authoritative. '
    'Provider identity for a specific transaction is captured in '
    'payment_transactions.provider (text) — see 007_payments.sql. '
    'See AUDIT.md for the full explanation.';
END $$;
