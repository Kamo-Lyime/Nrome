-- =====================================================
-- FIX APPOINTMENTS RLS POLICIES
-- =====================================================
-- This fixes Row Level Security so users can see their appointments
-- =====================================================

-- Force drop ALL existing policies using dynamic SQL
DO $$ 
DECLARE 
    policy_record RECORD;
BEGIN
    FOR policy_record IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'appointments' 
          AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON appointments', policy_record.policyname);
        RAISE NOTICE 'Dropped policy: %', policy_record.policyname;
    END LOOP;
END $$;

-- Enable RLS on appointments table
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- POLICY 1: Patients can view appointments they created
-- =====================================================
CREATE POLICY "Patients can view their own appointments"
ON appointments
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- =====================================================
-- POLICY 2: Practitioners can view appointments booked with them
-- =====================================================
CREATE POLICY "Practitioners can view their appointments"
ON appointments
FOR SELECT
TO authenticated
USING (
    practitioner_id IN (
        SELECT id 
        FROM medical_practitioners 
        WHERE owner_user_id = auth.uid()
    )
);

-- =====================================================
-- POLICY 3: Anyone authenticated can INSERT appointments
-- =====================================================
CREATE POLICY "Authenticated users can create appointments"
ON appointments
FOR INSERT
TO authenticated
WITH CHECK (true);

-- =====================================================
-- POLICY 4: Patients can update their own appointments
-- =====================================================
CREATE POLICY "Patients can update their appointments"
ON appointments
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- =====================================================
-- POLICY 5: Practitioners can update appointments with them
-- =====================================================
CREATE POLICY "Practitioners can update their appointments"
ON appointments
FOR UPDATE
TO authenticated
USING (
    practitioner_id IN (
        SELECT id 
        FROM medical_practitioners 
        WHERE owner_user_id = auth.uid()
    )
)
WITH CHECK (
    practitioner_id IN (
        SELECT id 
        FROM medical_practitioners 
        WHERE owner_user_id = auth.uid()
    )
);

-- =====================================================
-- POLICY 6: Admins can view all appointments (optional)
-- =====================================================
CREATE POLICY "Admins can view all appointments"
ON appointments
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 
        FROM user_role_assignments 
        WHERE user_id = auth.uid() 
        AND role = 'admin'
    )
);

-- =====================================================
-- Verify policies
-- =====================================================
-- Run this to see all policies on appointments table:
/*
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'appointments';
*/

-- =====================================================
-- TEST QUERIES
-- =====================================================
-- After running this script, test with:
/*
-- As a patient, should see your appointments:
SELECT * FROM appointments WHERE user_id = auth.uid();

-- As a practitioner, should see appointments with you:
SELECT a.* 
FROM appointments a
JOIN medical_practitioners mp ON a.practitioner_id = mp.id
WHERE mp.owner_user_id = auth.uid();
*/
