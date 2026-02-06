-- Fix missing pharmacy manager role assignment and user profile
-- This creates both the user_profiles record and role assignment

-- Automatic fix for most recent user and pharmacy
-- Step 1: Create user_profiles record
INSERT INTO user_profiles (id, full_name, email, phone_number, created_at)
SELECT 
  u.id,
  u.raw_user_meta_data->>'full_name' as full_name,
  u.email,
  u.raw_user_meta_data->>'phone' as phone_number,
  u.created_at
FROM auth.users u
WHERE u.id = (SELECT id FROM auth.users ORDER BY created_at DESC LIMIT 1)
ON CONFLICT (id) DO NOTHING;

-- Step 2: Create role assignment
INSERT INTO user_role_assignments (user_id, role, organization_id, is_active)
SELECT 
  (SELECT id FROM auth.users ORDER BY created_at DESC LIMIT 1) as user_id,
  'pharmacy_manager' as role,
  (SELECT id FROM pharmacies ORDER BY created_at DESC LIMIT 1) as organization_id,
  true as is_active
ON CONFLICT DO NOTHING;
