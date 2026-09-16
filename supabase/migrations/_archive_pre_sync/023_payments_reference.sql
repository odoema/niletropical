-- 023: persist provider reference so payment-status can poll.
ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS provider text,
  ADD COLUMN IF NOT EXISTS provider_reference text;

CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_provider_reference
  ON payments (provider_reference)
  WHERE provider_reference IS NOT NULL;
