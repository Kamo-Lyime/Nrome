-- =====================================================
-- MIGRATE DATA FROM MEDICAL_PRACTITIONERS TO PRACTITIONERS
-- =====================================================
-- This migrates existing practitioner data to the new table structure

-- =====================================================
-- STEP 1: Check what data exists in medical_practitioners
-- =====================================================

SELECT 
    'medical_practitioners' as source_table,
    COUNT(*) as total_count
FROM medical_practitioners;

-- Show the data
SELECT 
    id,
    owner_user_id,
    name,
    profession,
    phone_number,
    email_address,
    verified,
    created_at
FROM medical_practitioners
ORDER BY created_at DESC;

-- =====================================================
-- STEP 2: Check if practitioners table is empty
-- =====================================================

SELECT 
    'practitioners' as target_table,
    COUNT(*) as total_count
FROM practitioners;

-- =====================================================
-- STEP 3: Migrate data (only if not already migrated)
-- =====================================================

-- Insert into practitioners table, mapping columns appropriately
INSERT INTO practitioners (
    id,
    user_id,
    full_name,
    profession,
    registration_number,
    address,
    verification_status,
    created_at,
    updated_at
)
SELECT 
    mp.id,
    mp.owner_user_id as user_id,
    mp.name as full_name,
    mp.profession,
    COALESCE(mp.license_number, mp.registration_number, 'PENDING') as registration_number,
    COALESCE(mp.practice_address, 'Not provided') as address,
    CASE 
        WHEN mp.verified = true THEN 'verified'::TEXT
        ELSE 'pending_review'::TEXT
    END as verification_status,
    mp.created_at,
    COALESCE(mp.updated_at, NOW()) as updated_at
FROM medical_practitioners mp
WHERE NOT EXISTS (
    SELECT 1 FROM practitioners p WHERE p.id = mp.id
)
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- STEP 4: Verify migration
-- =====================================================

SELECT 
    'MIGRATION SUMMARY' as summary,
    (SELECT COUNT(*) FROM medical_practitioners) as source_count,
    (SELECT COUNT(*) FROM practitioners) as target_count,
    (SELECT COUNT(*) FROM practitioners WHERE verification_status = 'verified') as verified_count;

-- Show migrated data
SELECT 
    id,
    user_id,
    full_name,
    profession,
    verification_status,
    created_at
FROM practitioners
ORDER BY created_at DESC;

-- =====================================================
-- STEP 5: Update missing fields in practitioners
-- =====================================================

-- Add consultation_fee, currency, availability from medical_practitioners if they exist
UPDATE practitioners p
SET 
    consultation_fee = mp.consultation_fee,
    currency = mp.currency,
    availability = COALESCE(mp.availability, 'Mon-Fri 9AM-5PM'),
    profile_image_url = mp.profile_image_url
FROM medical_practitioners mp
WHERE p.id = mp.id
    AND p.consultation_fee IS NULL;

-- =====================================================
-- COMPLETE!
-- =====================================================
-- After running this:
-- 1. Data migrated from medical_practitioners → practitioners
-- 2. verified=true → verification_status='verified'
-- 3. owner_user_id → user_id
-- 4. name → full_name
-- 
-- Next step: Run fix_appointments_foreign_key.sql
-- =====================================================
