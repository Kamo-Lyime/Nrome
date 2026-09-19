-- =====================================================
-- VERIFY AND FIX APPOINTMENTS TABLE FOREIGN KEY
-- =====================================================
-- This script ensures the appointments table properly references
-- medical_practitioners table and fixes any orphaned records

-- =====================================================
-- STEP 1: Check current foreign key constraint
-- =====================================================

SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.table_name = 'appointments' 
    AND tc.constraint_type = 'FOREIGN KEY'
    AND kcu.column_name = 'practitioner_id';

-- =====================================================
-- STEP 2: Find orphaned appointments (practitioner_id not in medical_practitioners)
-- =====================================================

SELECT 
    a.id,
    a.booking_id,
    a.practitioner_id,
    a.practitioner_name,
    a.patient_name,
    a.appointment_date,
    a.created_at
FROM appointments a
WHERE a.practitioner_id IS NOT NULL
    AND NOT EXISTS (
        SELECT 1 FROM medical_practitioners mp 
        WHERE mp.id = a.practitioner_id
    )
ORDER BY a.created_at DESC;

-- =====================================================
-- STEP 3: Create practitioner profiles for orphaned appointments
-- =====================================================
-- This creates basic practitioner profiles based on appointment data
-- so that existing appointments can be preserved

INSERT INTO medical_practitioners (
    id,
    owner_user_id,
    name,
    profession,
    phone_number,
    verified,
    rating,
    total_patients,
    created_at,
    updated_at
)
SELECT DISTINCT
    a.practitioner_id as id,
    NULL as owner_user_id, -- Will need to be linked manually or via admin
    a.practitioner_name as name,
    'Medical Practitioner' as profession,
    '' as phone_number, -- Empty string to satisfy NOT NULL constraint
    false as verified,
    0 as rating,
    0 as total_patients,
    MIN(a.created_at) as created_at,
    NOW() as updated_at
FROM appointments a
WHERE a.practitioner_id IS NOT NULL
    AND NOT EXISTS (
        SELECT 1 FROM medical_practitioners mp 
        WHERE mp.id = a.practitioner_id
    )
GROUP BY a.practitioner_id, a.practitioner_name
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- STEP 4: Verify the fix
-- =====================================================

-- Check if any orphaned appointments remain
SELECT 
    COUNT(*) as orphaned_appointment_count
FROM appointments a
WHERE a.practitioner_id IS NOT NULL
    AND NOT EXISTS (
        SELECT 1 FROM medical_practitioners mp 
        WHERE mp.id = a.practitioner_id
    );

-- =====================================================
-- STEP 5: Show all practitioners with appointment counts
-- =====================================================

SELECT 
    mp.id,
    mp.name,
    mp.profession,
    mp.email_address,
    mp.verified,
    au.email as owner_email,
    au.raw_user_meta_data->>'role' as owner_role,
    COUNT(a.id) as appointment_count
FROM medical_practitioners mp
LEFT JOIN auth.users au ON mp.owner_user_id = au.id
LEFT JOIN appointments a ON a.practitioner_id = mp.id
GROUP BY mp.id, mp.name, mp.profession, mp.email_address, mp.verified, au.email, au.raw_user_meta_data
ORDER BY appointment_count DESC, mp.created_at DESC;

-- =====================================================
-- COMPLETE!
-- =====================================================
-- All appointments should now have valid practitioner references
-- New appointments will save to Supabase successfully
