-- =====================================================
-- CHECK RLS (ROW LEVEL SECURITY) POLICIES
-- =====================================================
-- RLS might be blocking public access to practitioners

-- =====================================================
-- STEP 1: Check if RLS is enabled
-- =====================================================

SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'medical_practitioners';

-- =====================================================
-- STEP 2: Show all policies on medical_practitioners
-- =====================================================

SELECT 
    schemaname,
    tablename,
    policyname as policy_name,
    permissive,
    roles,
    cmd as command,
    qual as using_expression,
    with_check
FROM pg_policies
WHERE tablename = 'medical_practitioners'
ORDER BY policyname;

-- =====================================================
-- STEP 3: Test if you can SELECT without auth
-- =====================================================
-- This simulates what nurse.html does when loading practitioners

SELECT 
    id,
    name,
    profession,
    verified,
    created_at
FROM medical_practitioners
WHERE verified = true
LIMIT 5;

-- =====================================================
-- COMMON ISSUES & FIXES
-- =====================================================
--
-- Issue 1: RLS is enabled but no SELECT policy for anonymous users
--   Fix: Create policy allowing public SELECT on verified practitioners
--
--   CREATE POLICY "Public can view verified practitioners"
--   ON medical_practitioners
--   FOR SELECT
--   USING (verified = true);
--
-- Issue 2: RLS is blocking all access
--   Fix: Temporarily disable RLS (NOT RECOMMENDED for production)
--
--   ALTER TABLE medical_practitioners DISABLE ROW LEVEL SECURITY;
--
-- Issue 3: Policy exists but uses wrong column name
--   Fix: Drop old policy and create correct one
--
--   DROP POLICY IF EXISTS "old_policy_name" ON medical_practitioners;
--   CREATE POLICY "Public can view verified practitioners"
--   ON medical_practitioners
--   FOR SELECT
--   USING (verified = true);
--
-- =====================================================
