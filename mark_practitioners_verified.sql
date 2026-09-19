-- =====================================================
-- MARK PRACTITIONERS AS VERIFIED
-- =====================================================
-- This script marks all practitioners as verified so they
-- appear on the public listing on nurse.html

-- =====================================================
-- OPTION 1: Mark ALL practitioners as verified (for testing)
-- =====================================================

UPDATE medical_practitioners
SET verified = true
WHERE verified = false OR verified IS NULL;

-- =====================================================
-- OPTION 2: Mark specific practitioners as verified by name
-- =====================================================

-- Uncomment and modify the names below to verify specific practitioners:

-- UPDATE medical_practitioners
-- SET verified = true
-- WHERE name IN (
--     'Dr Kgaisang',
--     'Kamohelo Mokoteli',
--     'Thabiso Sibiya',
--     'Boikhutso Mokoteli'
-- );

-- =====================================================
-- OPTION 3: Mark practitioners as verified by email
-- =====================================================

-- UPDATE medical_practitioners
-- SET verified = true
-- WHERE email_address IN (
--     'email1@example.com',
--     'email2@example.com'
-- );

-- =====================================================
-- VERIFICATION - Show all practitioners and their status
-- =====================================================

SELECT 
    id,
    name,
    profession,
    phone_number,
    email_address,
    verified,
    created_at,
    owner_user_id
FROM medical_practitioners
ORDER BY created_at DESC;

-- =====================================================
-- COMPLETE!
-- =====================================================
-- Run this script to mark practitioners as verified
-- They will then appear on nurse.html public listing
