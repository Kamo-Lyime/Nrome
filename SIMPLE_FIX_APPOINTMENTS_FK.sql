-- =====================================================
-- SIMPLE FIX: Update appointments foreign key only
-- =====================================================
-- This ONLY changes the foreign key constraint
-- NO data migration, NO other changes

-- Show current constraint
SELECT 
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS references_table
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'appointments'
    AND kcu.column_name = 'practitioner_id';

-- Drop old constraint
ALTER TABLE appointments
DROP CONSTRAINT IF EXISTS appointments_practitioner_id_fkey;

-- Add new constraint to practitioners table
ALTER TABLE appointments
ADD CONSTRAINT appointments_practitioner_id_fkey
FOREIGN KEY (practitioner_id)
REFERENCES practitioners(id)
ON DELETE CASCADE;

-- Verify new constraint
SELECT 
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS references_table,
    CASE 
        WHEN ccu.table_name = 'practitioners' THEN '✅ FIXED'
        ELSE '❌ STILL WRONG'
    END as status
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'appointments'
    AND kcu.column_name = 'practitioner_id';
