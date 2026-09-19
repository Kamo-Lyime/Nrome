-- =====================================================
-- FIX PRESCRIPTION FOREIGN KEY CONSTRAINTS
-- =====================================================

-- Check current FK constraints
SELECT
    conname AS constraint_name,
    conrelid::regclass AS table_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'prescriptions'::regclass
    AND contype = 'f';

-- Drop problematic FK constraints
ALTER TABLE prescriptions 
DROP CONSTRAINT IF EXISTS prescriptions_uploaded_by_fkey;

ALTER TABLE prescriptions 
DROP CONSTRAINT IF EXISTS prescriptions_patient_id_fkey;

-- Recreate FK constraints pointing to auth.users instead of user_profiles
-- This is safer since every authenticated user is in auth.users

-- uploaded_by should reference the practitioner's auth user
ALTER TABLE prescriptions
ADD CONSTRAINT prescriptions_uploaded_by_fkey 
FOREIGN KEY (uploaded_by) 
REFERENCES auth.users(id) 
ON DELETE SET NULL;

-- patient_id should reference the patient's auth user  
ALTER TABLE prescriptions
ADD CONSTRAINT prescriptions_patient_id_fkey 
FOREIGN KEY (patient_id) 
REFERENCES auth.users(id) 
ON DELETE SET NULL;

-- Verify the changes
SELECT
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'prescriptions'::regclass
    AND contype = 'f';

-- =====================================================
-- COMPLETE! ✅
-- =====================================================
-- ✅ Dropped user_profiles FK constraints
-- ✅ Added auth.users FK constraints
-- ✅ Set to ON DELETE SET NULL for safety
-- 
-- Run in Supabase SQL Editor
-- Then re-run create_prescription_upload_function.sql
-- Then hard refresh dashboard and test
-- =====================================================
