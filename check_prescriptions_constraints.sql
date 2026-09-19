-- =====================================================
-- CHECK ALL CONSTRAINTS ON PRESCRIPTIONS TABLE
-- =====================================================

-- Check all check constraints
SELECT 
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'prescriptions'::regclass
    AND contype = 'c';

-- Check all constraints (including foreign keys, unique, etc.)
SELECT 
    conname AS constraint_name,
    contype AS constraint_type,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'prescriptions'::regclass
ORDER BY contype, conname;

-- Also check the full table definition
SELECT 
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'prescriptions'
    AND table_schema = 'public'
ORDER BY ordinal_position;
