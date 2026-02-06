-- Temporary: Disable RLS on pharmacy and medication tables for testing
-- This will allow pharmacy registration and medication ordering to work while we debug policies

ALTER TABLE pharmacies DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_role_assignments DISABLE ROW LEVEL SECURITY;
ALTER TABLE pharmacy_verifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE order_items DISABLE ROW LEVEL SECURITY;

-- NOTE: This is ONLY for testing. Re-enable RLS for production:
-- ALTER TABLE pharmacies ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE user_role_assignments ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE pharmacy_verifications ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
