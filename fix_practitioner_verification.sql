-- =====================================================
-- FIX: MARK ALL PRACTITIONERS AS VERIFIED
-- =====================================================
-- This makes ALL practitioners visible on the public listing
-- Run this AFTER running diagnose_practitioners.sql to confirm the issue

-- =====================================================
-- OPTION 1: Mark ALL practitioners as verified
-- =====================================================

UPDATE medical_practitioners 
SET verified = true
WHERE verified IS NULL OR verified = false;

-- =====================================================
-- OPTION 2: Mark only specific practitioners as verified
-- =====================================================
-- Uncomment and replace 'practitioner_id_here' with actual ID

-- UPDATE medical_practitioners 
-- SET verified = true
-- WHERE id = 'practitioner_id_here';

-- =====================================================
-- VERIFY THE CHANGE
-- =====================================================

SELECT 
    id,
    name,
    profession,
    CASE 
        WHEN verified = true THEN '✅ VERIFIED (will show on public listing)'
        ELSE '❌ NOT VERIFIED'
    END as status,
    created_at
FROM medical_practitioners
ORDER BY created_at DESC;

-- =====================================================
-- EXPECTED RESULT
-- =====================================================
-- All practitioners should show '✅ VERIFIED'
-- Then refresh nurse.html to see them appear
-- =====================================================
