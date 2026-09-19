-- =====================================================
-- FIX PRACTITIONER USER_ID MAPPING
-- =====================================================
-- Problem: Practitioners have records in the table but user_id is NULL or wrong
-- Solution: Map user_id from email_address matching auth.users.email

-- =====================================================
-- STEP 1: Check current state
-- =====================================================

SELECT 
    id,
    full_name,
    email_address,
    user_id,
    CASE 
        WHEN user_id IS NULL THEN '❌ Missing user_id'
        ELSE '✅ Has user_id'
    END as status
FROM practitioners
ORDER BY created_at DESC
LIMIT 10;

-- =====================================================
-- STEP 2: Update user_id by matching email_address
-- =====================================================

-- Update practitioners.user_id by matching email_address with auth.users.email
UPDATE practitioners p
SET user_id = u.id
FROM auth.users u
WHERE p.email_address = u.email
AND p.user_id IS NULL;

-- =====================================================
-- STEP 3: For practitioners from old medical_practitioners table
-- =====================================================

-- If there are practitioners that were migrated from medical_practitioners,
-- update their user_id from the old owner_user_id mapping
UPDATE practitioners p
SET user_id = mp.owner_user_id
FROM medical_practitioners mp
WHERE p.email_address = mp.email_address
AND p.user_id IS NULL
AND mp.owner_user_id IS NOT NULL;

-- =====================================================
-- STEP 4: Verify the fix
-- =====================================================

SELECT 
    id,
    full_name,
    email_address,
    user_id,
    CASE 
        WHEN user_id IS NULL THEN '❌ Still missing user_id'
        ELSE '✅ Fixed - has user_id'
    END as status
FROM practitioners
ORDER BY created_at DESC;

-- Check if practitioners can now be found by user_id
SELECT 
    'Total practitioners' as metric,
    COUNT(*) as count
FROM practitioners
UNION ALL
SELECT 
    'Practitioners with user_id' as metric,
    COUNT(*) as count
FROM practitioners
WHERE user_id IS NOT NULL
UNION ALL
SELECT 
    'Practitioners without user_id' as metric,
    COUNT(*) as count
FROM practitioners
WHERE user_id IS NULL;

-- =====================================================
-- COMPLETE! ✅
-- =====================================================
-- ✅ Updated user_id by matching email addresses
-- ✅ Updated user_id from old medical_practitioners table
-- 
-- Now practitioners should be able to see appointments in their dashboard!
-- Refresh dashboard.html and login as practitioner
-- =====================================================
