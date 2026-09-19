-- =====================================================
-- CHECK PRESCRIPTIONS PATIENT_ID VALUES
-- =====================================================
-- Use this to diagnose why patients aren't seeing prescriptions

-- Check all prescriptions with their patient info
SELECT 
    id,
    prescription_number,
    patient_name,
    patient_email,
    patient_id,
    uploaded_by,
    doctor_name,
    prescription_date,
    status,
    upload_date
FROM prescriptions
ORDER BY upload_date DESC
LIMIT 20;

-- Check if patient_id matches any auth.users
SELECT 
    p.prescription_number,
    p.patient_name,
    p.patient_email,
    p.patient_id,
    u.id as auth_user_id,
    u.email as auth_email,
    CASE 
        WHEN p.patient_id = u.id THEN '✅ MATCH'
        WHEN p.patient_id IS NULL THEN '⚠️ NULL'
        ELSE '❌ MISMATCH'
    END as match_status
FROM prescriptions p
LEFT JOIN auth.users u ON p.patient_email = u.email
ORDER BY p.upload_date DESC
LIMIT 20;

-- Count prescriptions by match status
SELECT 
    status,
    COUNT(*) as count
FROM (
    SELECT 
        CASE 
            WHEN p.patient_id IS NULL THEN 'NULL patient_id'
            WHEN u.id IS NOT NULL AND p.patient_id = u.id THEN 'MATCHED to auth.users'
            WHEN u.id IS NOT NULL AND p.patient_id != u.id THEN 'MISMATCHED'
            ELSE 'No matching user'
        END as status
    FROM prescriptions p
    LEFT JOIN auth.users u ON p.patient_email = u.email
) subquery
GROUP BY status;

-- =====================================================
-- 🔍 DIAGNOSIS TIPS:
-- =====================================================
-- If patient_id is NULL: Practitioner selected manual entry or user_id wasn't captured
-- If MISMATCHED: patient_id doesn't match the actual user's auth.users.id
-- If No matching user: Patient email doesn't exist in auth.users (guest/unregistered)
-- 
-- TO FIX NULL patient_id:
-- UPDATE prescriptions SET patient_id = (SELECT id FROM auth.users WHERE email = prescriptions.patient_email) WHERE patient_id IS NULL;
-- =====================================================
