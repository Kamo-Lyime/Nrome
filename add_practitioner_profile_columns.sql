-- =====================================================
-- ADD MISSING PRACTITIONER PROFILE COLUMNS
-- =====================================================
-- This adds public-facing profile columns to the practitioners table

-- Add consultation fee and currency
ALTER TABLE practitioners 
ADD COLUMN IF NOT EXISTS consultation_fee DECIMAL(10, 2);

ALTER TABLE practitioners 
ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'ZAR';

-- Add availability schedule
ALTER TABLE practitioners 
ADD COLUMN IF NOT EXISTS availability TEXT;

-- Add experience years
ALTER TABLE practitioners 
ADD COLUMN IF NOT EXISTS experience_years INTEGER;

-- Add serving locations
ALTER TABLE practitioners 
ADD COLUMN IF NOT EXISTS serving_locations TEXT;

-- Add service description (optional - for additional info)
ALTER TABLE practitioners 
ADD COLUMN IF NOT EXISTS service_description TEXT;

-- Add profile image URL
ALTER TABLE practitioners 
ADD COLUMN IF NOT EXISTS profile_image_url TEXT;

-- Add qualifications (if not already exists)
ALTER TABLE practitioners 
ADD COLUMN IF NOT EXISTS qualifications TEXT;

-- Add medical scheme billing support flag (already in schema but ensure it exists)
ALTER TABLE practitioners 
ADD COLUMN IF NOT EXISTS medical_scheme_billing_supported BOOLEAN DEFAULT false;

-- =====================================================
-- VERIFICATION QUERY
-- =====================================================
-- Check that all columns were added
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'practitioners'
    AND table_schema = 'public'
    AND column_name IN (
        'consultation_fee', 'currency', 'availability', 
        'experience_years', 'serving_locations', 'service_description',
        'profile_image_url', 'qualifications', 'specialty',
        'medical_scheme_billing_supported'
    )
ORDER BY column_name;

-- =====================================================
-- ✅ COMPLETE!
-- =====================================================
-- Now practitioners can have complete public profiles
-- Run in Supabase SQL Editor
-- =====================================================
