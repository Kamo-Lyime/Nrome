-- =====================================================
-- SET submitted_at FOR EXISTING PRACTITIONERS
-- =====================================================
-- This updates existing verified practitioners to have submitted_at
-- so they appear in the public listing

-- Update verified practitioners that don't have submitted_at
UPDATE practitioners
SET submitted_at = created_at
WHERE verification_status = 'verified'
  AND submitted_at IS NULL;

-- Verify the update
SELECT 
    id,
    full_name,
    profession,
    verification_status,
    CASE 
        WHEN submitted_at IS NOT NULL THEN '✅ HAS submitted_at'
        ELSE '❌ MISSING submitted_at'
    END as status,
    submitted_at,
    created_at
FROM practitioners
WHERE verification_status = 'verified'
ORDER BY created_at DESC;
