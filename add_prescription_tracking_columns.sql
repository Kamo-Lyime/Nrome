-- =====================================================
-- ADD PATIENT/PRACTITIONER TRACKING TO PRESCRIPTIONS TABLE
-- =====================================================
-- Add columns to track which patient the prescription is for
-- and which practitioner uploaded it

-- =====================================================
-- STEP 1: Add missing columns
-- =====================================================

ALTER TABLE prescriptions 
    ADD COLUMN IF NOT EXISTS patient_id UUID REFERENCES auth.users(id),
    ADD COLUMN IF NOT EXISTS uploaded_by UUID REFERENCES auth.users(id),
    ADD COLUMN IF NOT EXISTS patient_name TEXT,
    ADD COLUMN IF NOT EXISTS patient_email TEXT;

-- =====================================================
-- STEP 2: Create indexes for better query performance
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_prescriptions_patient_id ON prescriptions(patient_id);
CREATE INDEX IF NOT EXISTS idx_prescriptions_uploaded_by ON prescriptions(uploaded_by);

-- =====================================================
-- STEP 3: Add RLS policies for prescriptions
-- =====================================================

-- Enable RLS
ALTER TABLE prescriptions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view own prescriptions" ON prescriptions;
DROP POLICY IF EXISTS "Practitioners can view uploaded prescriptions" ON prescriptions;
DROP POLICY IF EXISTS "Users can upload prescriptions" ON prescriptions;

-- Patients can view their own prescriptions
CREATE POLICY "Users can view own prescriptions"
ON prescriptions
FOR SELECT
TO authenticated
USING (patient_id = auth.uid());

-- Practitioners can view prescriptions they uploaded
CREATE POLICY "Practitioners can view uploaded prescriptions"
ON prescriptions
FOR SELECT
TO authenticated
USING (uploaded_by = auth.uid());

-- Authenticated users can upload prescriptions
CREATE POLICY "Users can upload prescriptions"
ON prescriptions
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Users can update their own prescriptions
CREATE POLICY "Users can update own prescriptions"
ON prescriptions
FOR UPDATE
TO authenticated
USING (patient_id = auth.uid() OR uploaded_by = auth.uid());

-- =====================================================
-- STEP 4: Verify changes
-- =====================================================

SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'prescriptions'
    AND column_name IN ('patient_id', 'uploaded_by', 'patient_name', 'patient_email')
ORDER BY column_name;

-- =====================================================
-- COMPLETE! ✅
-- =====================================================
-- ✅ Added patient_id, uploaded_by, patient_name, patient_email columns
-- ✅ Created indexes for better performance
-- ✅ Added RLS policies for privacy
-- 
-- Now practitioners can upload prescriptions for specific patients!
-- Refresh dashboard.html and try uploading a prescription
-- =====================================================
