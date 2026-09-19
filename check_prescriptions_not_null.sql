-- =====================================================
-- CHECK ALL NOT NULL COLUMNS IN PRESCRIPTIONS TABLE
-- =====================================================

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'prescriptions'
    AND table_schema = 'public'
    AND is_nullable = 'NO'
ORDER BY ordinal_position;

-- Also check for any enum types
SELECT 
    column_name,
    data_type,
    udt_name
FROM information_schema.columns
WHERE table_name = 'prescriptions'
    AND table_schema = 'public'
    AND data_type = 'USER-DEFINED'
ORDER BY ordinal_position;
