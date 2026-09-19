-- =====================================================
-- FIX APPOINTMENTS FOREIGN KEY CONSTRAINT
-- =====================================================
-- The appointments table references medical_practitioners,
-- but we're using the practitioners table.
-- This script fixes the foreign key constraint.

-- =====================================================
-- STEP 1: Check current foreign key constraint
-- =====================================================

SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'appointments'
    AND kcu.column_name = 'practitioner_id';

-- =====================================================
-- STEP 2: Drop the old foreign key constraint
-- =====================================================

ALTER TABLE appointments
DROP CONSTRAINT IF EXISTS appointments_practitioner_id_fkey;

-- =====================================================
-- STEP 3: Create new foreign key to practitioners table
-- =====================================================

ALTER TABLE appointments
ADD CONSTRAINT appointments_practitioner_id_fkey
FOREIGN KEY (practitioner_id)
REFERENCES practitioners(id)
ON DELETE CASCADE;

-- =====================================================
-- STEP 4: Verify the new constraint
-- =====================================================

SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'appointments'
    AND kcu.column_name = 'practitioner_id';

-- =====================================================
-- EXPECTED RESULT
-- =====================================================
-- foreign_table_name should now be 'practitioners' (not 'medical_practitioners')
-- 
-- After running this script:
-- 1. Appointments can be saved to Supabase
-- 2. No more localStorage fallback
-- 3. Foreign key now references the correct table
-- =====================================================
