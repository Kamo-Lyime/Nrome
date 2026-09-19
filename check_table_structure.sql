-- =====================================================
-- CHECK MEDICAL_PRACTITIONERS TABLE STRUCTURE
-- =====================================================
-- This script shows you exactly what columns exist in your table
-- and which ones are required (NOT NULL)

-- =====================================================
-- STEP 1: Show all columns in medical_practitioners table
-- =====================================================

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default,
    CASE 
        WHEN is_nullable = 'NO' AND column_default IS NULL THEN '⚠️ REQUIRED (NOT NULL, NO DEFAULT)'
        WHEN is_nullable = 'NO' AND column_default IS NOT NULL THEN '✓ NOT NULL (has default)'
        ELSE '○ Optional'
    END as requirement_status
FROM information_schema.columns
WHERE table_name = 'medical_practitioners'
ORDER BY ordinal_position;

-- =====================================================
-- STEP 2: Show constraints on the table
-- =====================================================

SELECT 
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    CASE tc.constraint_type
        WHEN 'PRIMARY KEY' THEN '🔑 Primary Key'
        WHEN 'FOREIGN KEY' THEN '🔗 Foreign Key'
        WHEN 'UNIQUE' THEN '⭐ Unique'
        WHEN 'CHECK' THEN '✓ Check Constraint'
        ELSE tc.constraint_type
    END as constraint_info
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'medical_practitioners'
ORDER BY tc.constraint_type, kcu.column_name;

-- =====================================================
-- COMPLETE!
-- =====================================================
-- This shows you exactly what columns are required
-- Use this to update the trigger or frontend code
