-- =====================================================
-- COMPLETE FIX: CONSOLIDATE TO PRACTITIONERS TABLE
-- =====================================================
-- This script does everything needed to fix the appointment saving issue
-- Run this in Supabase SQL Editor

-- =====================================================
-- PART 1: Ensure practitioners table has all needed columns
-- =====================================================

ALTER TABLE practitioners 
    ADD COLUMN IF NOT EXISTS consultation_fee NUMERIC(10,2);

ALTER TABLE practitioners 
    ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'ZAR';

ALTER TABLE practitioners 
    ADD COLUMN IF NOT EXISTS availability TEXT;

ALTER TABLE practitioners 
    ADD COLUMN IF NOT EXISTS profile_image_url TEXT;

ALTER TABLE practitioners 
    ADD COLUMN IF NOT EXISTS experience_years INTEGER;

ALTER TABLE practitioners 
    ADD COLUMN IF NOT EXISTS service_description TEXT;

ALTER TABLE practitioners 
    ADD COLUMN IF NOT EXISTS serving_locations TEXT;

ALTER TABLE practitioners 
    ADD COLUMN IF NOT EXISTS qualifications TEXT;

ALTER TABLE practitioners 
    ADD COLUMN IF NOT EXISTS license_number TEXT;

ALTER TABLE practitioners 
    ADD COLUMN IF NOT EXISTS phone_number TEXT;

ALTER TABLE practitioners 
    ADD COLUMN IF NOT EXISTS email_address TEXT;

-- =====================================================
-- PART 2: Migrate data from medical_practitioners to practitioners
-- =====================================================

-- Only migrate if medical_practitioners exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'medical_practitioners') THEN
        
        -- Insert practitioners that don't already exist
        -- Only use columns that exist in medical_practitioners table
        INSERT INTO practitioners (
            id,
            user_id,
            full_name,
            profession,
            registration_number,
            address,
            phone_number,
            email_address,
            verification_status,
            submitted_at,
            created_at,
            updated_at
        )
        SELECT 
            mp.id,
            mp.owner_user_id as user_id,
            mp.name as full_name,
            mp.profession,
            'PENDING' as registration_number,
            'Not provided - please update' as address,
            COALESCE(mp.phone_number, '') as phone_number,
            mp.email_address,
            CASE 
                WHEN mp.verified = true THEN 'verified'::TEXT
                ELSE 'pending_review'::TEXT
            END as verification_status,
            mp.created_at as submitted_at,  -- Set submitted_at to creation date
            mp.created_at,
            COALESCE(mp.updated_at, NOW()) as updated_at
        FROM medical_practitioners mp
        WHERE NOT EXISTS (
            SELECT 1 FROM practitioners p WHERE p.id = mp.id
        )
        ON CONFLICT (id) DO UPDATE SET
            submitted_at = EXCLUDED.submitted_at
        WHERE practitioners.submitted_at IS NULL;
        
        -- Update any existing practitioners that don't have submitted_at
        UPDATE practitioners
        SET submitted_at = created_at
        WHERE verification_status = 'verified'
          AND submitted_at IS NULL;
        
        RAISE NOTICE 'Migration from medical_practitioners completed';
    ELSE
        RAISE NOTICE 'medical_practitioners table does not exist, skipping migration';
    END IF;
END $$;

-- =====================================================
-- PART 3: Fix appointments foreign key constraint
-- =====================================================

-- Drop old constraint
ALTER TABLE appointments
DROP CONSTRAINT IF EXISTS appointments_practitioner_id_fkey;

-- Create new constraint pointing to practitioners table
ALTER TABLE appointments
ADD CONSTRAINT appointments_practitioner_id_fkey
FOREIGN KEY (practitioner_id)
REFERENCES practitioners(id)
ON DELETE CASCADE;

-- =====================================================
-- PART 4: Fix RLS policies for public access
-- =====================================================

-- Enable RLS if not already enabled
ALTER TABLE practitioners ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Public can view verified practitioners" ON practitioners;
DROP POLICY IF EXISTS "Users can view own practitioner profile" ON practitioners;
DROP POLICY IF EXISTS "Users can insert own practitioner profile" ON practitioners;
DROP POLICY IF EXISTS "Users can update own practitioner profile" ON practitioners;
DROP POLICY IF EXISTS "Users can delete own practitioner profile" ON practitioners;

-- Create new policies
CREATE POLICY "Public can view verified practitioners"
    ON practitioners
    FOR SELECT
    USING (verification_status = 'verified');

CREATE POLICY "Users can view own practitioner profile"
    ON practitioners
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "Users can insert own practitioner profile"
    ON practitioners
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own practitioner profile"
    ON practitioners
    FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own practitioner profile"
    ON practitioners
    FOR DELETE
    TO authenticated
    USING (user_id = auth.uid());

-- =====================================================
-- PART 5: Verify the fix
-- =====================================================

-- Show practitioners
SELECT 
    'PRACTITIONERS' as table_name,
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE verification_status = 'verified') as verified_count
FROM practitioners;

-- Show appointments FK constraint
SELECT 
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS references_table,
    'appointments → practitioners' as description
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'appointments'
    AND kcu.column_name = 'practitioner_id';

-- Show sample practitioners
SELECT 
    id,
    full_name,
    profession,
    verification_status,
    consultation_fee,
    currency,
    created_at
FROM practitioners
ORDER BY created_at DESC
LIMIT 5;

-- =====================================================
-- COMPLETE! ✅
-- =====================================================
-- What this script did:
-- 1. Added missing columns to practitioners table
-- 2. Migrated data from medical_practitioners (if it exists)
-- 3. Fixed appointments FK to point to practitioners
-- 4. Set up RLS policies for public access
-- 
-- Now appointments should save to Supabase successfully!
-- Refresh nurse.html to test.
-- =====================================================
