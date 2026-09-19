-- =====================================================
-- FIX RLS POLICIES FOR PRACTITIONERS PUBLIC LISTING
-- =====================================================

-- =====================================================
-- STEP 1: Check current RLS status
-- =====================================================

SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'practitioners';

-- =====================================================
-- STEP 2: View existing policies
-- =====================================================

SELECT 
    schemaname,
    tablename,
    policyname as policy_name,
    permissive,
    roles,
    cmd as command,
    qual as using_expression
FROM pg_policies
WHERE tablename = 'practitioners'
ORDER BY policyname;

-- =====================================================
-- STEP 3: Drop old policies and create new ones
-- =====================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can insert own practitioner profile" ON practitioners;
DROP POLICY IF EXISTS "Users can view own practitioner profile" ON practitioners;
DROP POLICY IF EXISTS "Users can update own practitioner profile" ON practitioners;
DROP POLICY IF EXISTS "Public can view verified practitioners" ON practitioners;
DROP POLICY IF EXISTS "Authenticated users can manage documents" ON practitioners;

-- Policy 1: Public can view VERIFIED practitioners
CREATE POLICY "Public can view verified practitioners"
    ON practitioners
    FOR SELECT
    USING (verification_status = 'verified');

-- Policy 2: Users can view their OWN practitioner profile (any status)
CREATE POLICY "Users can view own practitioner profile"
    ON practitioners
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

-- Policy 3: Users can insert their own practitioner profile
CREATE POLICY "Users can insert own practitioner profile"
    ON practitioners
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

-- Policy 4: Users can update their OWN practitioner profile
CREATE POLICY "Users can update own practitioner profile"
    ON practitioners
    FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Policy 5: Users can delete their OWN practitioner profile
CREATE POLICY "Users can delete own practitioner profile"
    ON practitioners
    FOR DELETE
    TO authenticated
    USING (user_id = auth.uid());

-- =====================================================
-- STEP 4: Verify policies are active
-- =====================================================

SELECT 
    policyname as policy_name,
    cmd as command,
    CASE 
        WHEN cmd = 'SELECT' AND qual LIKE '%verified%' THEN '✅ Allows public to see verified practitioners'
        WHEN cmd = 'SELECT' AND qual LIKE '%auth.uid()%' THEN '✅ Allows users to see own profile'
        WHEN cmd = 'INSERT' THEN '✅ Allows authenticated users to create profile'
        WHEN cmd = 'UPDATE' THEN '✅ Allows users to update own profile'
        WHEN cmd = 'DELETE' THEN '✅ Allows users to delete own profile'
        ELSE '❓ Other policy'
    END as purpose
FROM pg_policies
WHERE tablename = 'practitioners'
ORDER BY cmd, policyname;

-- =====================================================
-- STEP 5: Test public SELECT access
-- =====================================================
-- This simulates what nurse.html does when loading practitioners

SELECT 
    id,
    full_name,
    profession,
    consultation_fee,
    currency,
    availability,
    verification_status
FROM practitioners
WHERE verification_status = 'verified'
LIMIT 5;

-- =====================================================
-- COMPLETE!
-- =====================================================
-- Now public users (not logged in) can view verified practitioners
-- Authenticated users can create/update/delete their own profiles
-- =====================================================
