-- =====================================================
-- FIX APPOINTMENTS RLS POLICIES - UPDATED FOR PRACTITIONERS TABLE
-- =====================================================
-- This fixes Row Level Security so practitioners can see their appointments
-- Problem: RLS policies still reference medical_practitioners instead of practitioners
-- =====================================================

-- Force drop ALL existing policies
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
-- ✅ UPDATED to use 'practitioners' table with 'user_id'
-- =====================================================
CREATE POLICY "Practitioners can view their appointments"
ON appointments
FOR SELECT
TO authenticated
USING (
    practitioner_id IN (
        SELECT id 
        FROM practitioners 
        WHERE user_id = auth.uid()
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
-- ✅ UPDATED to use 'practitioners' table with 'user_id'
-- =====================================================
CREATE POLICY "Practitioners can update their appointments"
ON appointments
FOR UPDATE
TO authenticated
USING (
    practitioner_id IN (
        SELECT id 
        FROM practitioners 
        WHERE user_id = auth.uid()
    )
)
WITH CHECK (
    practitioner_id IN (
        SELECT id 
        FROM practitioners 
        WHERE user_id = auth.uid()
    )
);

-- =====================================================
-- VERIFY POLICIES
-- =====================================================
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    '✅ Policy active' as status
FROM pg_policies
WHERE tablename = 'appointments'
ORDER BY policyname;

-- =====================================================
-- COMPLETE! ✅
-- =====================================================
-- ✅ Dropped all old RLS policies (including problematic admin policy)
-- ✅ Created new policies using 'practitioners' table
-- ✅ Changed owner_user_id → user_id
-- ✅ Removed admin policy that caused "permission denied for table users" error
-- 
-- Now both patients AND practitioners should see their appointments!
-- Refresh dashboard.html as patient and practitioner
-- =====================================================
