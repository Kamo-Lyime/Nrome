-- Add bank account columns to pharmacies table (if not already present)
-- This allows pharmacies to store their banking details for payments

ALTER TABLE pharmacies 
  ADD COLUMN IF NOT EXISTS bank_account_number TEXT;

-- Update pharmacy_verifications table to track document submission
ALTER TABLE pharmacy_verifications
  ADD COLUMN IF NOT EXISTS documents_metadata JSONB,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Add comment
COMMENT ON COLUMN pharmacy_verifications.documents_metadata IS 'Stores information about uploaded verification documents';

-- Check current verification statuses
SELECT pharmacy_id, verification_status, documents_metadata, updated_at
FROM pharmacy_verifications
ORDER BY updated_at DESC;
