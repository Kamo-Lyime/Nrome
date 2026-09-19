-- =====================================================
-- DIAGNOSE PRACTITIONER LISTING ISSUE
-- =====================================================
-- Run this to see exactly what's in your database
-- NOTE: This checks the PRACTITIONERS table (not medical_practitioners)

-- =====================================================
-- STEP 1: Count all practitioners
-- =====================================================

SELECT 
    'TOTAL PRACTITIONERS' as metric,
    COUNT(*) as count
FROM practitioners;

-- =====================================================
-- STEP 2: Count by verification status
-- =====================================================

SELECT 
    CASE 
        WHEN verification_status = 'verified' THEN '✅ VERIFIED (should show on public listing)'
        WHEN verification_status = 'pending_review' THEN '⏳ PENDING REVIEW (not shown)'
        WHEN verification_status = 'under_review' THEN '🔍 UNDER REVIEW (not shown)'
        WHEN verification_status = 'rejected' THEN '❌ REJECTED (not shown)'
        WHEN verification_status = 'draft' THEN '📝 DRAFT (not shown)'
        ELSE '⚠️ UNKNOWN STATUS'
    END as status,
    COUNT(*) as count
FROM practitioners
GROUP BY verification_status;

-- =====================================================
-- STEP 3: Show all practitioners with required fields
-- =====================================================

SELECT 
    id,
    full_name,
    profession,
    registration_number,
    consultation_fee,
    currency,
    availability,
    CASE 
        WHEN full_name IS NOT NULL AND 
             profession IS NOT NULL AND 
             registration_number IS NOT NULL AND 
             consultation_fee IS NOT NULL AND 
             currency IS NOT NULL AND 
             availability IS NOT NULL AND 
             address IS NOT NULL 
        THEN '✅ COMPLETE'
        ELSE '❌ MISSING FIELDS'
    END as completeness,
    CASE 
        WHEN verification_status = 'verified' THEN '✅ VERIFIED'
        ELSE verification_status
    END as status,
    submitted_at,
    created_at
FROM practitioners
ORDER BY created_at DESC;

-- =====================================================
-- STEP 4: Check for incomplete profiles
-- =====================================================

SELECT 
    id,
    full_name,
    CASE WHEN full_name IS NULL THEN '❌ Missing' ELSE '✅' END as has_name,
    CASE WHEN profession IS NULL THEN '❌ Missing' ELSE '✅' END as has_profession,
    CASE WHEN registration_number IS NULL THEN '❌ Missing' ELSE '✅' END as has_reg_number,
    CASE WHEN consultation_fee IS NULL THEN '❌ Missing' ELSE '✅' END as has_fee,
    CASE WHEN currency IS NULL THEN '❌ Missing' ELSE '✅' END as has_currency,
    CASE WHEN availability IS NULL THEN '❌ Missing' ELSE '✅' END as has_availability,
    CASE WHEN address IS NULL THEN '❌ Missing' ELSE '✅' END as has_address,
    verification_status
FROM practitioners
WHERE verification_status = 'verified'
ORDER BY created_at DESC;

-- =====================================================
-- EXPECTED RESULTS & FIXES
-- =====================================================
-- 
-- If practitioners exist but verification_status != 'verified':
--   → Run: verify_practitioners.sql
--
-- If practitioners have verification_status = 'verified' but missing required fields:
--   → Those practitioners won't show (incomplete registration)
--   → User needs to complete the registration form
--
-- If no practitioners exist:
--   → Create a new practitioner account
--   → Fill out registration form on nurse.html
--   → Submit for review
--   → Run verify_practitioners.sql to mark as verified
--
-- If you see "RLS policy blocking access" error:
--   → Run: fix_practitioners_rls.sql
--
-- =====================================================
