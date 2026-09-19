-- =====================================================
-- CHECK PRESCRIPTION STATUS ENUM VALUES
-- =====================================================

-- Check if prescription_status enum exists and what values it has
SELECT 
    e.enumlabel as enum_value,
    e.enumsortorder
FROM pg_type t 
JOIN pg_enum e ON t.oid = e.enumtypid  
WHERE t.typname = 'prescription_status'
ORDER BY e.enumsortorder;

-- Also check the actual column type
SELECT 
    column_name,
    data_type,
    udt_name,
    column_default
FROM information_schema.columns
WHERE table_name = 'prescriptions'
    AND column_name = 'status';
