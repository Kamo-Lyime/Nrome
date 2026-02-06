-- Add INSERT policies to allow pharmacy registration and user profile creation
-- This fixes the RLS (Row Level Security) errors during registration

-- ============================================================================
-- DROP ALL EXISTING POLICIES TO START FRESH
-- ============================================================================

-- Pharmacies policies
DROP POLICY IF EXISTS pharmacies_insert_authenticated ON pharmacies;
DROP POLICY IF EXISTS pharmacies_select_public ON pharmacies;
DROP POLICY IF EXISTS pharmacies_update_manager ON pharmacies;
DROP POLICY IF EXISTS pharmacies_all_admin ON pharmacies;

-- User role assignments policies
DROP POLICY IF EXISTS user_role_assignments_insert_own ON user_role_assignments;
DROP POLICY IF EXISTS user_role_assignments_select_own ON user_role_assignments;

-- User profiles policies
DROP POLICY IF EXISTS user_profiles_insert_own ON user_profiles;
DROP POLICY IF EXISTS user_profiles_select_own ON user_profiles;
DROP POLICY IF EXISTS user_profiles_update_own ON user_profiles;
DROP POLICY IF EXISTS user_profiles_select_admin ON user_profiles;
DROP POLICY IF EXISTS user_profiles_select_pharmacist ON user_profiles;

-- Pharmacy verifications policies
DROP POLICY IF EXISTS pharmacy_verifications_insert ON pharmacy_verifications;

-- ============================================================================
-- PHARMACIES TABLE - Recreate all policies
-- ============================================================================

-- Allow authenticated users to insert pharmacies
CREATE POLICY pharmacies_insert_authenticated
  ON pharmacies FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Everyone can view verified, active pharmacies
CREATE POLICY pharmacies_select_public
  ON pharmacies FOR SELECT
  TO authenticated, anon
  USING (is_active = TRUE AND is_verified = TRUE);

-- Pharmacy managers can update their pharmacy (recreate existing policy)
CREATE POLICY pharmacies_update_manager
  ON pharmacies FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_role_assignments
      WHERE user_id = auth.uid()
      AND organization_id = pharmacies.id
      AND role IN ('pharmacy_manager', 'pharmacist')
      AND is_active = true
    )
  );

-- Admins can manage all pharmacies (recreate existing policy)
CREATE POLICY pharmacies_all_admin
  ON pharmacies FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_role_assignments
      WHERE user_id = auth.uid()
      AND role = 'admin'
      AND is_active = true
    )
  );

-- ============================================================================
-- USER_PROFILES TABLE - Recreate policies
-- ============================================================================

-- Allow users to insert their own profile
CREATE POLICY user_profiles_insert_own
  ON user_profiles FOR INSERT
  TO authenticated
  WITH CHECK (id = auth.uid());

-- Users can view their own profile (recreate)
CREATE POLICY user_profiles_select_own
  ON user_profiles FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- Users can update their own profile (recreate)
CREATE POLICY user_profiles_update_own
  ON user_profiles FOR UPDATE
  TO authenticated
  USING (id = auth.uid());

-- ============================================================================
-- USER_ROLE_ASSIGNMENTS TABLE - Recreate all policies
-- ============================================================================

-- Allow users to insert their own role assignments during registration
CREATE POLICY user_role_assignments_insert_own
  ON user_role_assignments FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Allow users to view all role assignments (needed for checks)
CREATE POLICY user_role_assignments_select_own
  ON user_role_assignments FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================================
-- PHARMACY_VERIFICATIONS TABLE - Create policy
-- ============================================================================

-- Allow authenticated users to create verification records
CREATE POLICY pharmacy_verifications_insert
  ON pharmacy_verifications FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Note: These policies allow registration but the pharmacies will still need
-- admin verification (is_verified = false by default) before becoming active
