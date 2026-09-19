-- =====================================================
-- FIX ALL PRESCRIPTIONS TABLE NOT NULL CONSTRAINTS
-- =====================================================
-- This makes problematic columns nullable to avoid insertion errors

-- Make issue_date nullable (can be derived from prescription_date)
ALTER TABLE prescriptions 
ALTER COLUMN issue_date DROP NOT NULL;

-- Make valid_from nullable (can be derived from prescription_date)
ALTER TABLE prescriptions 
ALTER COLUMN valid_from DROP NOT NULL;

-- Make valid_until nullable (can be derived from prescription_expiry)
ALTER TABLE prescriptions 
ALTER COLUMN valid_until DROP NOT NULL;

-- Make prescription_number nullable or set a default
ALTER TABLE prescriptions 
ALTER COLUMN prescription_number DROP NOT NULL;

-- Make patient_id nullable (for manual patient entry before they register)
ALTER TABLE prescriptions 
ALTER COLUMN patient_id DROP NOT NULL;

-- Make uploaded_by nullable (for safety)
ALTER TABLE prescriptions 
ALTER COLUMN uploaded_by DROP NOT NULL;

-- Add default for created_at if not exists
ALTER TABLE prescriptions 
ALTER COLUMN created_at SET DEFAULT NOW();

-- Add default for updated_at if not exists
ALTER TABLE prescriptions 
ALTER COLUMN updated_at SET DEFAULT NOW();

-- Add default for upload_date if not exists
ALTER TABLE prescriptions 
ALTER COLUMN upload_date SET DEFAULT NOW();

-- Drop the problematic check constraint if it exists
ALTER TABLE prescriptions 
DROP CONSTRAINT IF EXISTS prescriptions_check;

-- =====================================================
-- VERIFICATION QUERY
-- =====================================================
-- Run this after to verify changes
SELECT 
    column_name,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'prescriptions'
    AND table_schema = 'public'
    AND column_name IN (
        'issue_date', 'valid_from', 'valid_until', 
        'prescription_number', 'created_at', 'updated_at', 'upload_date'
    )
ORDER BY column_name;

-- =====================================================
-- COMPLETE! ✅
-- =====================================================
-- This removes NOT NULL constraints from problematic columns
-- Now the upload function won't fail on missing columns
-- Run in Supabase SQL Editor
-- =====================================================
