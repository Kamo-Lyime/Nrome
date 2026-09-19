-- =====================================================
-- FIX PRACTITIONER ACCOUNTS AND APPOINTMENT FOREIGN KEY ISSUES
-- =====================================================
-- This script fixes:
-- 1. Creates medical_practitioners records for users with role='practitioner' who don't have one
-- 2. Adds a trigger to automatically create practitioner profiles on signup
-- 3. Ensures appointments can be saved to Supabase instead of localStorage

-- =====================================================
-- STEP 1: Ensure medical_practitioners table has all required columns
-- =====================================================

-- Add missing columns if they don't exist
ALTER TABLE medical_practitioners 
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE medical_practitioners 
    ADD COLUMN IF NOT EXISTS email_address TEXT;

ALTER TABLE medical_practitioners 
    ADD COLUMN IF NOT EXISTS verified BOOLEAN DEFAULT FALSE;

ALTER TABLE medical_practitioners 
    ADD COLUMN IF NOT EXISTS rating NUMERIC DEFAULT 0;

ALTER TABLE medical_practitioners 
    ADD COLUMN IF NOT EXISTS total_patients INTEGER DEFAULT 0;

ALTER TABLE medical_practitioners 
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- =====================================================
-- STEP 2: Create missing practitioner profiles for existing users
-- =====================================================

-- Insert practitioner records for users who signed up as practitioner but don't have a profile
INSERT INTO medical_practitioners (
    owner_user_id,
    name,
    profession,
    phone_number,
    email_address,
    verified,
    rating,
    total_patients,
    created_at,
    updated_at
)
SELECT 
    au.id as owner_user_id,
    COALESCE(au.raw_user_meta_data->>'full_name', 'Practitioner') as name,
    'Medical Practitioner' as profession,
    COALESCE(au.phone, '') as phone_number, -- Use auth phone or empty string
    au.email as email_address,
    false as verified,
    0 as rating,
    0 as total_patients,
    au.created_at,
    NOW() as updated_at
FROM auth.users au
WHERE 
    au.raw_user_meta_data->>'role' = 'practitioner'
    AND NOT EXISTS (
        SELECT 1 FROM medical_practitioners mp 
        WHERE mp.owner_user_id = au.id
    );

-- =====================================================
-- STEP 3: Create function to auto-create practitioner profile on signup
-- =====================================================

CREATE OR REPLACE FUNCTION handle_new_practitioner_signup()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if the new user has role='practitioner' in metadata
    IF NEW.raw_user_meta_data->>'role' = 'practitioner' THEN
        -- Insert a basic practitioner profile
        INSERT INTO medical_practitioners (
            owner_user_id,
            name,
            profession,
            phone_number,
            email_address,
            verified,
            rating,
            total_patients,
            created_at,
            updated_at
        ) VALUES (
            NEW.id,
            COALESCE(NEW.raw_user_meta_data->>'full_name', 'Practitioner'),
            'Medical Practitioner',
            COALESCE(NEW.phone, ''), -- Use auth phone or empty string
            NEW.email,
            false,
            0,
            0,
            NOW(),
            NOW()
        )
        ON CONFLICT (owner_user_id) DO NOTHING; -- Prevent duplicates if profile already exists
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- STEP 4: Create trigger to run on new user signup
-- =====================================================

-- Drop the trigger if it already exists
DROP TRIGGER IF EXISTS on_auth_user_created_create_practitioner ON auth.users;

-- Create the trigger
CREATE TRIGGER on_auth_user_created_create_practitioner
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_practitioner_signup();

-- =====================================================
-- STEP 5: Add missing owner_user_id constraint if needed
-- =====================================================

-- Ensure owner_user_id has unique constraint to prevent duplicate profiles
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'medical_practitioners_owner_user_id_key'
    ) THEN
        ALTER TABLE medical_practitioners 
        ADD CONSTRAINT medical_practitioners_owner_user_id_key 
        UNIQUE (owner_user_id);
    END IF;
END $$;

-- =====================================================
-- STEP 6: Verification - Show results
-- =====================================================

-- Show all practitioners and their auth user info
SELECT 
    mp.id as practitioner_id,
    mp.name,
    mp.profession,
    mp.owner_user_id,
    au.email,
    au.raw_user_meta_data->>'role' as user_role,
    mp.verified,
    mp.created_at
FROM medical_practitioners mp
LEFT JOIN auth.users au ON mp.owner_user_id = au.id
ORDER BY mp.created_at DESC;

-- =====================================================
-- STEP 7: Show count of users vs practitioners
-- =====================================================

SELECT 
    'Total Practitioner Users' as category,
    COUNT(*) as count
FROM auth.users
WHERE raw_user_meta_data->>'role' = 'practitioner'

UNION ALL

SELECT 
    'Practitioner Profiles' as category,
    COUNT(*) as count
FROM medical_practitioners

UNION ALL

SELECT 
    'Patient Users' as category,
    COUNT(*) as count
FROM auth.users
WHERE raw_user_meta_data->>'role' = 'patient'
   OR raw_user_meta_data->>'role' IS NULL;

-- =====================================================
-- COMPLETE! 
-- =====================================================
-- Run this script in your Supabase SQL Editor
-- All existing practitioner users now have profiles
-- New practitioner signups will automatically get profiles
-- Appointments will now save to Supabase successfully!
