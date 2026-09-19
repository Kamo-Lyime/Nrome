-- =====================================================
-- CHECK APPOINTMENTS STATUS
-- =====================================================
-- Check what appointments exist and if they need migration

-- =====================================================
-- STEP 1: Check existing appointments
-- =====================================================

SELECT 
    id,
    booking_id,
    patient_name,
    practitioner_id,
    appointment_date,
    status,
    created_at
FROM appointments
ORDER BY created_at DESC
LIMIT 20;

-- =====================================================
-- STEP 2: Check if practitioner_ids match practitioners table
-- =====================================================

SELECT 
    a.id as appointment_id,
    a.booking_id,
    a.practitioner_id,
    CASE 
        WHEN p.id IS NOT NULL THEN '✅ Valid - in practitioners table'
        WHEN mp.id IS NOT NULL THEN '❌ Old - from medical_practitioners table'
        ELSE '⚠️ Invalid - not found in any table'
    END as practitioner_status,
    COALESCE(p.full_name, mp.name) as practitioner_name
FROM appointments a
LEFT JOIN practitioners p ON a.practitioner_id = p.id
LEFT JOIN medical_practitioners mp ON a.practitioner_id = mp.id
ORDER BY a.created_at DESC
LIMIT 20;

-- =====================================================
-- STEP 3: Check for appointments that need practitioner_id update
-- =====================================================

SELECT 
    COUNT(*) as total_appointments,
    COUNT(CASE WHEN p.id IS NOT NULL THEN 1 END) as valid_practitioner_ids,
    COUNT(CASE WHEN p.id IS NULL AND mp.id IS NOT NULL THEN 1 END) as old_practitioner_ids,
    COUNT(CASE WHEN p.id IS NULL AND mp.id IS NULL THEN 1 END) as invalid_practitioner_ids
FROM appointments a
LEFT JOIN practitioners p ON a.practitioner_id = p.id
LEFT JOIN medical_practitioners mp ON a.practitioner_id = mp.id;
