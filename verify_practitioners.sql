-- =====================================================
-- MARK PRACTITIONERS AS VERIFIED  
-- (For practitioners table, not medical_practitioners)
-- =====================================================

-- =====================================================
-- STEP 1: View all practitioners and their status
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
        WHEN verification_status = 'verified' THEN '✅ VERIFIED (will show on public listing)'
        WHEN verification_status = 'pending_review' THEN '⏳ PENDING REVIEW'
        WHEN verification_status = 'under_review' THEN '🔍 UNDER REVIEW'
        WHEN verification_status = 'rejected' THEN '❌ REJECTED'
        WHEN verification_status = 'draft' THEN '📝 DRAFT'
        ELSE verification_status
    END as status,
    submitted_at,
    created_at
FROM practitioners
ORDER BY created_at DESC;

-- =====================================================
-- STEP 2: Mark ALL practitioners as verified
-- =====================================================

UPDATE practitioners 
SET 
    verification_status = 'verified',
    verified_at = NOW()
WHERE verification_status != 'verified';

-- =====================================================
-- STEP 3: Mark SPECIFIC practitioner as verified
-- =====================================================
-- Uncomment and replace 'practitioner_id_here' with actual ID

-- UPDATE practitioners 
-- SET 
--     verification_status = 'verified',
--     verified_at = NOW()
-- WHERE id = 'practitioner_id_here';

-- =====================================================
-- STEP 4: Verify the change
-- =====================================================

SELECT 
    id,
    full_name,
    profession,
    CASE 
        WHEN verification_status = 'verified' THEN '✅ VERIFIED'
        ELSE '❌ NOT VERIFIED'
    END as status,
    verified_at,
    created_at
FROM practitioners
ORDER BY created_at DESC;

-- =====================================================
-- EXPECTED RESULT
-- =====================================================
-- All practitioners should show '✅ VERIFIED'
-- Then refresh nurse.html to see them appear
-- =====================================================
