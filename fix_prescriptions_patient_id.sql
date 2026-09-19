-- =====================================================
-- FIX PRESCRIPTIONS PATIENT_ID
-- =====================================================
-- This updates prescriptions to link them to the correct patient user_id

-- Step 1: Show prescriptions that need fixing
SELECT 
    prescription_number,
    patient_name,
    patient_email,
    patient_id as current_patient_id,
    (SELECT id FROM auth.users WHERE email = prescriptions.patient_email) as correct_patient_id,
    CASE 
        WHEN patient_id IS NULL THEN '⚠️ Will set patient_id'
        WHEN patient_id != (SELECT id FROM auth.users WHERE email = prescriptions.patient_email) THEN '⚠️ Will update patient_id'
        ELSE '✅ Already correct'
    END as action
FROM prescriptions
WHERE patient_email IS NOT NULL;

-- Step 2: Update prescriptions with NULL patient_id
UPDATE prescriptions
SET patient_id = (
    SELECT id 
    FROM auth.users 
    WHERE email = prescriptions.patient_email
)
WHERE patient_id IS NULL 
  AND patient_email IS NOT NULL
  AND EXISTS (SELECT 1 FROM auth.users WHERE email = prescriptions.patient_email);

-- Step 3: Update prescriptions with incorrect patient_id
UPDATE prescriptions
SET patient_id = (
    SELECT id 
    FROM auth.users 
    WHERE email = prescriptions.patient_email
)
WHERE patient_id IS NOT NULL
  AND patient_email IS NOT NULL
  AND patient_id != (SELECT id FROM auth.users WHERE email = prescriptions.patient_email LIMIT 1)
  AND EXISTS (SELECT 1 FROM auth.users WHERE email = prescriptions.patient_email);

-- Step 4: Verify the fix
SELECT 
    COUNT(*) as total_prescriptions,
    COUNT(patient_id) as prescriptions_with_patient_id,
    COUNT(*) - COUNT(patient_id) as prescriptions_without_patient_id,
    COUNT(CASE WHEN patient_id = (SELECT id FROM auth.users WHERE email = prescriptions.patient_email) THEN 1 END) as correctly_linked,
    COUNT(CASE WHEN patient_id != (SELECT id FROM auth.users WHERE email = prescriptions.patient_email) THEN 1 END) as mismatched
FROM prescriptions
WHERE patient_email IS NOT NULL;

-- =====================================================
-- ✅ COMPLETE!
-- =====================================================
-- Run check_prescriptions_patient_id.sql to verify the fix
-- Then refresh the patient dashboard to see prescriptions
-- =====================================================
