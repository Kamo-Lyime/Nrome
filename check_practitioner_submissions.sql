-- ==================================================
-- CHECK AND FIX EXISTING PRACTITIONER SUBMISSIONS
-- ==================================================
-- Run this in Supabase SQL Editor to check your submissions

-- 1. View all practitioner submissions (check if yours is there)
SELECT 
    id,
    full_name,
    profession,
    registration_number,
    verification_status,
    created_at,
    submitted_at
FROM practitioners
ORDER BY created_at DESC
LIMIT 20;

-- 2. Update any 'pending_documents' status to 'pending_review' 
-- (This fixes submissions made before the code was updated)
UPDATE practitioners
SET 
    verification_status = 'pending_review',
    submitted_at = COALESCE(submitted_at, created_at)
WHERE verification_status = 'pending_documents'
AND id IN (
    -- Only update if they have all required documents uploaded
    SELECT DISTINCT p.id
    FROM practitioners p
    INNER JOIN practitioner_documents pd ON p.id = pd.practitioner_id
    GROUP BY p.id
    HAVING COUNT(DISTINCT pd.document_type) >= 4
);

-- 3. Verify the update worked
SELECT 
    id,
    full_name,
    verification_status,
    submitted_at,
    (SELECT COUNT(*) FROM practitioner_documents WHERE practitioner_id = practitioners.id) as document_count
FROM practitioners
WHERE verification_status = 'pending_review'
ORDER BY created_at DESC;

-- 4. Check verification_requests table
SELECT 
    vr.id,
    vr.practitioner_id,
    p.full_name,
    vr.status,
    vr.submitted_at,
    vr.reviewed_at
FROM verification_requests vr
INNER JOIN practitioners p ON vr.practitioner_id = p.id
ORDER BY vr.submitted_at DESC
LIMIT 10;
