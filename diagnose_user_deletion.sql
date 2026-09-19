-- =====================================================
-- DIAGNOSE USER DELETION ISSUES
-- =====================================================
-- This script helps identify what's preventing user deletion
-- Run this to find ALL foreign key constraints blocking deletion
-- =====================================================

-- =====================================================
-- STEP 1: Find ALL foreign keys pointing to auth.users
-- =====================================================

SELECT 
    tc.table_schema,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    rc.delete_rule,
    tc.constraint_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
JOIN information_schema.referential_constraints AS rc
    ON tc.constraint_name = rc.constraint_name
    AND tc.table_schema = rc.constraint_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND ccu.table_schema = 'auth'
    AND ccu.table_name = 'users'
    AND tc.table_schema = 'public'
ORDER BY tc.table_name, tc.constraint_name;

-- =====================================================
-- STEP 2: Check if there are any records in tables that might prevent deletion
-- =====================================================

-- Find out which tables have data that references auth.users
-- (This will show you which tables need CASCADE delete)

-- Note: Replace 'USER_UUID_HERE' with the actual UUID of the user you're trying to delete
-- to see which tables have records for that user

/*
-- Example: Check prescriptions
SELECT COUNT(*) as prescription_count FROM prescriptions WHERE user_id = 'USER_UUID_HERE';

-- Example: Check medication_orders
SELECT COUNT(*) as order_count FROM medication_orders WHERE user_id = 'USER_UUID_HERE';

-- Example: Check appointments (if exists)
SELECT COUNT(*) as appointment_count FROM appointments WHERE patient_id = 'USER_UUID_HERE';
*/
