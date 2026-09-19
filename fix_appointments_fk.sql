-- =====================================================
-- FIX APPOINTMENTS FOREIGN KEY
-- =====================================================
-- Problem: appointments.practitioner_id FK still references medical_practitioners
-- Solution: Drop old FK, add new FK to practitioners table

-- =====================================================
-- STEP 1: Check current FK constraint
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
WHERE tc.table_name = 'appointments'
    AND tc.constraint_type = 'FOREIGN KEY'
    AND kcu.column_name = 'practitioner_id';

-- =====================================================
-- STEP 2: Drop old FK constraint
-- =====================================================

ALTER TABLE appointments 
    DROP CONSTRAINT IF EXISTS appointments_practitioner_id_fkey;

-- =====================================================
-- STEP 3: Add new FK constraint to practitioners table
-- =====================================================

ALTER TABLE appointments 
    ADD CONSTRAINT appointments_practitioner_id_fkey 
    FOREIGN KEY (practitioner_id) 
    REFERENCES practitioners(id) 
    ON DELETE CASCADE;

-- =====================================================
-- STEP 4: Verify the new FK constraint
-- =====================================================

SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    '✅ Fixed - now points to practitioners' as status
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.table_name = 'appointments'
    AND tc.constraint_type = 'FOREIGN KEY'
    AND kcu.column_name = 'practitioner_id';

-- =====================================================
-- COMPLETE! ✅
-- =====================================================
-- ✅ Dropped old FK constraint (medical_practitioners)
-- ✅ Added new FK constraint (practitioners)
-- 
-- Now appointments should save to Supabase!
-- Go to nurse.html and book a new appointment
-- It should save to the database (not localStorage)
-- =====================================================
