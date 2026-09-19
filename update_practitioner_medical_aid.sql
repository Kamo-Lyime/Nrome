-- =====================================================
-- UPDATE EXISTING PRACTITIONERS WITH MEDICAL AID FLAG
-- =====================================================

-- First, add the column if it doesn't exist
ALTER TABLE practitioners 
ADD COLUMN IF NOT EXISTS medical_scheme_billing_supported BOOLEAN DEFAULT false;

-- Update existing practitioner to show they accept medical aid
-- Replace 'your-email@example.com' with the actual email of the practitioner
UPDATE practitioners
SET medical_scheme_billing_supported = true
WHERE user_id IN (
    SELECT id FROM auth.users WHERE email = 'your-email@example.com'
);

-- OR update all practitioners to accept medical aid
-- Uncomment the line below to enable for all
-- UPDATE practitioners SET medical_scheme_billing_supported = true;

-- Verify the update
SELECT 
    full_name,
    profession,
    medical_scheme_billing_supported,
    email_address
FROM practitioners
WHERE medical_scheme_billing_supported = true;

-- =====================================================
-- ✅ COMPLETE!
-- =====================================================
-- Replace 'your-email@example.com' with practitioner's email
-- Then hard refresh nurse.html to see the badge
-- =====================================================
